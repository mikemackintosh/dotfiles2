package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestClusterName(t *testing.T) {
	for _, tc := range []struct{ vault, title, want string }{
		{"Certifly", "kube-prod", "certifly-prod"},
		{"Danger Close", "kube-prod", "danger-close-prod"},
		{"Ops", "kube-EU West", "ops-eu-west"},
		{"Ops", "kube-", "ops"},
	} {
		if got := clusterName(tc.vault, tc.title); got != tc.want {
			t.Errorf("clusterName(%q, %q) = %q, want %q", tc.vault, tc.title, got, tc.want)
		}
	}
}

func TestMapRoundTrip(t *testing.T) {
	cs := []cluster{
		{Name: "certifly-prod", VaultID: "nmhz2xay", VaultName: "Certifly", ItemID: "dvv24c4e", ItemTitle: "kube-prod", Sops: true, Registries: []string{"dockerhub", "ecr"}},
		{Name: "danger-close-prod", VaultID: "ehvtxiv3", VaultName: "Danger Close", ItemID: "j7h5czpy", ItemTitle: "kube-prod"},
	}
	path := filepath.Join(t.TempDir(), "sub", "kube-clusters.zsh")
	if err := writeMap(path, cs); err != nil {
		t.Fatal(err)
	}
	got, err := readMap(path)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, cs) {
		t.Errorf("round trip:\n got %+v\nwant %+v", got, cs)
	}
	if fi, _ := os.Stat(path); fi.Mode().Perm() != 0o600 {
		t.Errorf("mode = %v, want 0600", fi.Mode().Perm())
	}
}

func TestIsAgeIdentity(t *testing.T) {
	for _, tc := range []struct {
		v    string
		want bool
	}{
		{"AGE-SECRET-KEY-1QQQQ", true},
		{"# created: 2026-10-04\n# public key: age1abc\nAGE-SECRET-KEY-1QQQQ\n", true},
		{"age1abc", false},
		{"-----BEGIN OPENSSH PRIVATE KEY-----", false},
	} {
		if got := isAgeIdentity(tc.v); got != tc.want {
			t.Errorf("isAgeIdentity(%q) = %v, want %v", tc.v, got, tc.want)
		}
	}
}

func TestRegistries(t *testing.T) {
	sa := `{"type":"service_account","project_id":"p"}`
	for _, tc := range []struct {
		name  string
		val   map[string]string
		kinds []string
		warns int
	}{
		{"none", map[string]string{"server": "x"}, nil, 0},
		{"hub", map[string]string{"docker_pat": "dckr_pat_x"}, []string{"dockerhub"}, 0},
		{"generic partial", map[string]string{"registry_host": "r.example.com", "registry_user": "u"}, nil, 1},
		{"generic with scheme", map[string]string{"registry_host": "https://r.example.com", "registry_user": "u", "registry_token": "t"}, nil, 1},
		{"ecr ok", map[string]string{"ecr_registry": "123456789012.dkr.ecr.us-east-1.amazonaws.com", "aws_access_key_id": "A", "aws_secret_access_key": "S"}, []string{"ecr"}, 0},
		{"ecr bad host", map[string]string{"ecr_registry": "ecr.aws/x", "aws_access_key_id": "A", "aws_secret_access_key": "S"}, nil, 1},
		{"gcr ok", map[string]string{"gcr_host": "us-docker.pkg.dev", "gcr_json_key": sa}, []string{"gcr"}, 0},
		{"gcr not sa", map[string]string{"gcr_host": "gcr.io", "gcr_json_key": "{}"}, nil, 1},
		{"all four order", map[string]string{"gcr_host": "gcr.io", "gcr_json_key": sa, "docker_pat": "p",
			"registry_host": "r", "registry_user": "u", "registry_token": "t",
			"ecr_registry": "123456789012.dkr.ecr.eu-west-1.amazonaws.com", "aws_access_key_id": "A", "aws_secret_access_key": "S"},
			[]string{"dockerhub", "registry", "ecr", "gcr"}, 0},
	} {
		kinds, warns := registries(tc.val)
		if !reflect.DeepEqual(kinds, tc.kinds) || len(warns) != tc.warns {
			t.Errorf("%s: kinds %v warns %q; want %v and %d warning(s)", tc.name, kinds, warns, tc.kinds, tc.warns)
		}
	}
}
