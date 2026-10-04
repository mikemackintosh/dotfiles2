// Command kclusters finds kube-* items across 1Password vaults and writes
// the map `kuse` (zsh/kube.zsh) reads, so each cluster's vault and item are
// referenced by ID and never named in the dotfiles repo.
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

type cluster struct {
	Name, VaultID, VaultName, ItemID, ItemTitle string
}

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
		if missing, err := missingFields(c); err != nil {
			return nil, err
		} else if len(missing) > 0 {
			fmt.Fprintf(os.Stderr, "skip %s / %s: empty or missing %s\n",
				c.VaultName, c.ItemTitle, strings.Join(missing, ", "))
			continue
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

func missingFields(c cluster) ([]string, error) {
	raw, err := op("item", "get", c.ItemID, "--vault", c.VaultID, "--format", "json")
	if err != nil {
		return nil, err
	}
	var it opItem
	if err := json.Unmarshal(raw, &it); err != nil {
		return nil, fmt.Errorf("parse %s: %w", c.ItemTitle, err)
	}
	have := map[string]bool{}
	for _, f := range it.Fields {
		if f.Value != "" {
			have[f.Label] = true
		}
	}
	var missing []string
	for _, r := range required {
		if !have[r] {
			missing = append(missing, r)
		}
	}
	return missing, nil
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

// Map line: `  name  vaultID/itemID  # Vault Name / item title`.
var mapLine = regexp.MustCompile(`^\s+(\S+)\s+([a-z0-9]+)/([a-z0-9]+)\s+# (.*) / (.*)$`)

func readMap(path string) ([]cluster, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var cs []cluster
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if m := mapLine.FindStringSubmatch(sc.Text()); m != nil {
			cs = append(cs, cluster{m[1], m[2], m[4], m[3], m[5]})
		}
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
	fmt.Fprintln(tw, "CLUSTER\tVAULT\tITEM")
	for _, c := range cs {
		fmt.Fprintf(tw, "%s\t%s\t%s\n", c.Name, c.VaultName, c.ItemTitle)
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
			if p.VaultID != c.VaultID || p.ItemID != c.ItemID {
				mark = "~"
			}
			delete(was, c.Name)
		}
		fmt.Printf("%s %-24s %s / %s\n", mark, c.Name, c.VaultName, c.ItemTitle)
	}
	for _, c := range old {
		if _, gone := was[c.Name]; gone {
			fmt.Printf("- %-24s %s / %s\n", c.Name, c.VaultName, c.ItemTitle)
		}
	}
}
