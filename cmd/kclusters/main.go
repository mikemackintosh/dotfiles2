// Command kclusters finds kube-* items across 1Password vaults and writes
// the map `kuse` (zsh/kube.zsh) reads, so each cluster's vault and item are
// referenced by ID and never named in the dotfiles repo. An item may also
// carry a sops-age-key field (kuse points SOPS_AGE_KEY_CMD at it) and
// registry credentials (bin/registry-login reads them).
//
//	kclusters            list the synced clusters (no 1Password call)
//	kclusters sync [-n]  rescan 1Password and rewrite the map; -n prints only
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"text/tabwriter"
)

const prefix = "kube-"

var required = []string{"server", "ca", "token"}

// Optional per-cluster age identity for SOPS. Never read by this repo's
// shell code, only referenced: kuse sets SOPS_AGE_KEY_CMD to `op read` it.
const sopsField = "sops-age-key"

type cluster struct {
	Name, VaultID, VaultName, ItemID, ItemTitle string
	Sops                                        bool
	Registries                                  []string // kinds below, in that order
}

// Registry kinds an item can carry, and the fields each needs. All-or-
// nothing per kind: a partial set is reported, never half-used.
var registryKinds = []struct {
	Kind   string
	Fields []string
}{
	{"dockerhub", []string{"docker_pat"}}, // docker_user optional; else Personal/docker-hub's username
	{"registry", []string{"registry_host", "registry_user", "registry_token"}},
	{"ecr", []string{"ecr_registry", "aws_access_key_id", "aws_secret_access_key"}},
	{"gcr", []string{"gcr_host", "gcr_json_key"}},
}

var ecrHost = regexp.MustCompile(`^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$`)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "kclusters:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	path := mapPath()
	cmd := "ls"
	if len(args) > 0 {
		cmd, args = args[0], args[1:]
	}
	switch cmd {
	case "ls", "list":
		cs, err := readMap(path)
		if errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("no %s yet; run: kclusters sync", path)
		}
		if err != nil {
			return err
		}
		printTable(cs)
		return nil
	case "sync":
		dry := len(args) > 0 && args[0] == "-n"
		return sync(path, dry)
	case "-h", "--help", "help":
		fmt.Println("usage: kclusters [ls] | kclusters sync [-n]")
		return nil
	}
	return fmt.Errorf("unknown command %q (try: ls, sync)", cmd)
}

func mapPath() string {
	if p := os.Getenv("KUBE_CLUSTERS_FILE"); p != "" {
		return p
	}
	return filepath.Join(os.Getenv("HOME"), ".private", "kube-clusters.zsh")
}

func sync(path string, dry bool) error {
	found, err := discover()
	if err != nil {
		return err
	}
	old, err := readMap(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	printDiff(old, found)
	if dry {
		return nil
	}
	if err := writeMap(path, found); err != nil {
		return err
	}
	fmt.Printf("wrote %s (%d clusters)\n", path, len(found))
	return nil
}

type opItem struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Vault struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"vault"`
	Fields []struct {
		Label string `json:"label"`
		Value string `json:"value"`
	} `json:"fields"`
}

func op(args ...string) ([]byte, error) {
	var out bytes.Buffer
	c := exec.Command("op", args...)
	c.Stdout, c.Stderr = &out, os.Stderr
	if err := c.Run(); err != nil {
		return nil, fmt.Errorf("op %s: %w", strings.Join(args[:2], " "), err)
	}
	return out.Bytes(), nil
}

// discover lists every kube-* item, then fetches each one to confirm the
// fields the template needs are filled, so `kuse` fails here and not later.
func discover() ([]cluster, error) {
	raw, err := op("item", "list", "--format", "json")
	if err != nil {
		return nil, err
	}
	var items []opItem
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, fmt.Errorf("parse op item list: %w", err)
	}
	var cs []cluster
	seen := map[string]cluster{}
	for _, it := range items {
		if !strings.HasPrefix(it.Title, prefix) {
			continue
		}
		c := cluster{
			Name:    clusterName(it.Vault.Name, it.Title),
			VaultID: it.Vault.ID, VaultName: it.Vault.Name,
			ItemID: it.ID, ItemTitle: it.Title,
		}
		missing, sops, regs, warns, err := inspect(c)
		if err != nil {
			return nil, err
		}
		for _, w := range warns {
			fmt.Fprintf(os.Stderr, "warn %s / %s: %s\n", c.VaultName, c.ItemTitle, w)
		}
		c.Registries = regs
		if len(missing) > 0 {
			fmt.Fprintf(os.Stderr, "skip %s / %s: empty or missing %s\n",
				c.VaultName, c.ItemTitle, strings.Join(missing, ", "))
			continue
		}
		switch sops {
		case sopsValid:
			c.Sops = true
		case sopsInvalid:
			fmt.Fprintf(os.Stderr, "warn %s / %s: %s is not an age identity (no AGE-SECRET-KEY-1 line); SOPS not wired up\n",
				c.VaultName, c.ItemTitle, sopsField)
		}
		if prev, dup := seen[c.Name]; dup {
			return nil, fmt.Errorf("%s / %s and %s / %s both map to %q; rename one",
				prev.VaultName, prev.ItemTitle, c.VaultName, c.ItemTitle, c.Name)
		}
		seen[c.Name] = c
		cs = append(cs, c)
	}
	sort.Slice(cs, func(i, j int) bool { return cs[i].Name < cs[j].Name })
	return cs, nil
}

type sopsState int

const (
	sopsAbsent sopsState = iota
	sopsValid
	sopsInvalid
)

// inspect fetches the item once: required fields that are empty, whether
// the optional SOPS field holds an age identity, and which registry kinds
// are complete. Values are checked here, in-process, and never printed or
// written anywhere.
func inspect(c cluster) (missing []string, sops sopsState, regs, warns []string, err error) {
	raw, err := op("item", "get", c.ItemID, "--vault", c.VaultID, "--format", "json")
	if err != nil {
		return nil, sopsAbsent, nil, nil, err
	}
	var it opItem
	if err := json.Unmarshal(raw, &it); err != nil {
		return nil, sopsAbsent, nil, nil, fmt.Errorf("parse %s: %w", c.ItemTitle, err)
	}
	val := map[string]string{}
	for _, f := range it.Fields {
		if f.Value != "" {
			val[f.Label] = f.Value
		}
	}
	for _, r := range required {
		if val[r] == "" {
			missing = append(missing, r)
		}
	}
	if v, ok := val[sopsField]; ok {
		sops = sopsInvalid
		if isAgeIdentity(v) {
			sops = sopsValid
		}
	}
	regs, warns = registries(val)
	return missing, sops, regs, warns, nil
}

// registries returns the complete registry kinds in val, plus a warning for
// each kind that is partly filled or malformed.
func registries(val map[string]string) (kinds, warns []string) {
	for _, rk := range registryKinds {
		var have, lack []string
		for _, f := range rk.Fields {
			if val[f] != "" {
				have = append(have, f)
			} else {
				lack = append(lack, f)
			}
		}
		if len(have) == 0 {
			continue
		}
		if len(lack) > 0 {
			warns = append(warns, fmt.Sprintf("%s registry has %s but not %s; skipped",
				rk.Kind, strings.Join(have, ", "), strings.Join(lack, ", ")))
			continue
		}
		if msg := badRegistry(rk.Kind, val); msg != "" {
			warns = append(warns, rk.Kind+" registry skipped: "+msg)
			continue
		}
		kinds = append(kinds, rk.Kind)
	}
	return kinds, warns
}

func badRegistry(kind string, val map[string]string) string {
	switch kind {
	case "ecr":
		if !ecrHost.MatchString(val["ecr_registry"]) {
			return "ecr_registry should be <account>.dkr.ecr.<region>.amazonaws.com"
		}
	case "gcr":
		var k struct {
			Type string `json:"type"`
		}
		if json.Unmarshal([]byte(val["gcr_json_key"]), &k) != nil || k.Type != "service_account" {
			return "gcr_json_key is not a service-account JSON key"
		}
	case "registry":
		if strings.Contains(val["registry_host"], "/") {
			return "registry_host should be a bare host[:port], no scheme or path"
		}
	}
	return ""
}

// isAgeIdentity accepts a bare key or a pasted age-keygen file, whose
// `# created:` / `# public key:` comment lines sops skips too.
func isAgeIdentity(v string) bool {
	for _, l := range strings.Split(v, "\n") {
		if strings.HasPrefix(strings.TrimSpace(l), "AGE-SECRET-KEY-1") {
			return true
		}
	}
	return false
}

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

func slug(s string) string {
	return strings.Trim(nonSlug.ReplaceAllString(strings.ToLower(s), "-"), "-")
}

// clusterName is <vault>-<item minus kube->, since the same item title
// (kube-prod) is expected to recur across vaults.
func clusterName(vault, title string) string {
	v, rest := slug(vault), slug(strings.TrimPrefix(title, prefix))
	if rest == "" {
		return v
	}
	return v + "-" + rest
}

// Map line: `  name  vaultID/itemID  # Vault Name / item title`. KUBE_SOPS lines
// are the same minus the comment.
var (
	mapLine  = regexp.MustCompile(`^\s+(\S+)\s+([a-z0-9]+)/([a-z0-9]+)\s+# (.*) / (.*)$`)
	sopsLine = regexp.MustCompile(`^\s+(\S+)\s+[a-z0-9]+/[a-z0-9]+\s*$`)
	regLine  = regexp.MustCompile(`^\s+(\S+)\s+([a-z,]+)\s*$`)
)

func readMap(path string) ([]cluster, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var cs []cluster
	sops := map[string]bool{}
	regs := map[string][]string{}
	block := ""
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasSuffix(line, "=(") {
			block = strings.TrimSuffix(line, "=(")
			continue
		}
		switch block {
		case "KUBE_SYNCED":
			if m := mapLine.FindStringSubmatch(line); m != nil {
				cs = append(cs, cluster{Name: m[1], VaultID: m[2], VaultName: m[4], ItemID: m[3], ItemTitle: m[5]})
			}
		case "KUBE_SOPS":
			if m := sopsLine.FindStringSubmatch(line); m != nil {
				sops[m[1]] = true
			}
		case "KUBE_REGISTRIES":
			if m := regLine.FindStringSubmatch(line); m != nil {
				regs[m[1]] = strings.Split(m[2], ",")
			}
		}
	}
	for i := range cs {
		cs[i].Sops = sops[cs[i].Name]
		cs[i].Registries = regs[cs[i].Name]
	}
	return cs, sc.Err()
}

func render(cs []cluster) []byte {
	var b bytes.Buffer
	b.WriteString("# Generated by `kclusters sync`; rerun it rather than editing.\n")
	b.WriteString("KUBE_SYNCED=(\n")
	tw := tabwriter.NewWriter(&b, 0, 0, 2, ' ', 0)
	for _, c := range cs {
		fmt.Fprintf(tw, "  %s\t%s/%s\t# %s / %s\n", c.Name, c.VaultID, c.ItemID, c.VaultName, c.ItemTitle)
	}
	tw.Flush()
	b.WriteString(")\n")
	// Always written, even empty, so a sync that drops a key also drops it
	// from shells that reload this file.
	b.WriteString("# Clusters whose item has a valid " + sopsField + "; kuse sets SOPS_AGE_KEY_CMD.\n")
	b.WriteString("KUBE_SOPS=(\n")
	tw = tabwriter.NewWriter(&b, 0, 0, 2, ' ', 0)
	for _, c := range cs {
		if c.Sops {
			fmt.Fprintf(tw, "  %s\t%s/%s\n", c.Name, c.VaultID, c.ItemID)
		}
	}
	tw.Flush()
	b.WriteString(")\n")
	b.WriteString("# Registry kinds each item has complete credentials for; read by bin/registry-login.\n")
	b.WriteString("KUBE_REGISTRIES=(\n")
	tw = tabwriter.NewWriter(&b, 0, 0, 2, ' ', 0)
	for _, c := range cs {
		if len(c.Registries) > 0 {
			fmt.Fprintf(tw, "  %s\t%s\n", c.Name, strings.Join(c.Registries, ","))
		}
	}
	tw.Flush()
	b.WriteString(")\n")
	return b.Bytes()
}

func writeMap(path string, cs []cluster) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".kube-clusters-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(render(cs)); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

func printTable(cs []cluster) {
	tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "CLUSTER\tVAULT\tITEM\tSOPS\tREGISTRIES")
	for _, c := range cs {
		regs := strings.Join(c.Registries, ",")
		if regs == "" {
			regs = "-"
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\n", c.Name, c.VaultName, c.ItemTitle, yesNo(c.Sops), regs)
	}
	tw.Flush()
}

func printDiff(old, cur []cluster) {
	was := map[string]cluster{}
	for _, c := range old {
		was[c.Name] = c
	}
	for _, c := range cur {
		mark := "+"
		if p, ok := was[c.Name]; ok {
			mark = "="
			if p.VaultID != c.VaultID || p.ItemID != c.ItemID || p.Sops != c.Sops ||
				strings.Join(p.Registries, ",") != strings.Join(c.Registries, ",") {
				mark = "~"
			}
			delete(was, c.Name)
		}
		extra := ""
		if c.Sops {
			extra += "  +sops"
		}
		if len(c.Registries) > 0 {
			extra += "  +" + strings.Join(c.Registries, ",")
		}
		fmt.Printf("%s %-24s %s / %s%s\n", mark, c.Name, c.VaultName, c.ItemTitle, extra)
	}
	for _, c := range old {
		if _, gone := was[c.Name]; gone {
			fmt.Printf("- %-24s %s / %s\n", c.Name, c.VaultName, c.ItemTitle)
		}
	}
}

func yesNo(b bool) string {
	if b {
		return "yes"
	}
	return "-"
}
