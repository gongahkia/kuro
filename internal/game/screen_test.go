package game

import (
	"strings"
	"testing"
)

func TestTitleScreenSnapshot(t *testing.T) {
	renderer := NewBufferRenderer(80, 20)
	screen := NewTitleScreen(nil)
	screen.Render(renderer)
	output := renderer.String()

	expectedSnippets := []string{
		"K U R O",
		"Collect the torches. Survive three floors. Light the anchors below.",
		"> Start Run",
		"Help",
		"Quit",
	}
	for _, snippet := range expectedSnippets {
		if !strings.Contains(output, snippet) {
			t.Fatalf("expected snapshot to contain %q\noutput:\n%s", snippet, output)
		}
	}
}
