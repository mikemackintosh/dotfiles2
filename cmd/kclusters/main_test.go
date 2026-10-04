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
		{"certifly-prod", "nmhz2xay", "Certifly", "dvv24c4e", "kube-prod"},
		{"danger-close-prod", "ehvtxiv3", "Danger Close", "j7h5czpy", "kube-prod"},
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
