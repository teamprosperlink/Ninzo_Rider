package ridernotes

import (
	"strings"
	"testing"
)

func TestClipKeepsWholeRunes(t *testing.T) {
	for _, c := range []struct {
		in   string
		n    int
		want string
	}{
		{"short", 10, "short"},
		{"exactly", 7, "exactly"},
		{"too long", 3, "too"},
		{"नमस्ते दुनिया", 4, "नमस्"},
	} {
		if got := clip(c.in, c.n); got != c.want {
			t.Errorf("clip(%q, %d) = %q, want %q", c.in, c.n, got, c.want)
		}
	}
	if got := clip(strings.Repeat("a", maxTitle+5), maxTitle); len(got) != maxTitle {
		t.Errorf("%d", len(got))
	}
}
