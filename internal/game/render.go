package game

import (
	"strings"

	"github.com/gdamore/tcell/v2"
)

type StyleKind int

const (
	StyleDefault StyleKind = iota
	StyleTitle
	StyleMuted
	StylePlayer
	StyleEnemy
	StyleBoss
	StyleTorch
	StyleWall
	StyleExit
	StyleHazard
	StyleAccent
	StyleSuccess
	StyleDanger
)

type Renderer interface {
	Size() (int, int)
	Clear()
	SetCell(x, y int, ch rune, style StyleKind)
	DrawText(x, y int, text string, style StyleKind)
	DrawCentered(y int, text string, style StyleKind)
}

type TerminalRenderer struct {
	screen tcell.Screen
}

func NewTerminalRenderer(screen tcell.Screen) *TerminalRenderer {
	return &TerminalRenderer{screen: screen}
}

func (r *TerminalRenderer) Size() (int, int) {
	return r.screen.Size()
}

func (r *TerminalRenderer) Clear() {
	r.screen.Clear()
}

func (r *TerminalRenderer) SetCell(x, y int, ch rune, style StyleKind) {
	r.screen.SetContent(x, y, ch, nil, tcellStyle(style))
}

func (r *TerminalRenderer) DrawText(x, y int, text string, style StyleKind) {
	for i, ch := range text {
		r.SetCell(x+i, y, ch, style)
	}
}

func (r *TerminalRenderer) DrawCentered(y int, text string, style StyleKind) {
	width, _ := r.Size()
	x := max(0, (width-len([]rune(text)))/2)
	r.DrawText(x, y, text, style)
}

func (r *TerminalRenderer) Show() {
	r.screen.Show()
}

type BufferRenderer struct {
	width  int
	height int
	cells  [][]rune
}

func NewBufferRenderer(width, height int) *BufferRenderer {
	cells := make([][]rune, height)
	for y := range cells {
		cells[y] = make([]rune, width)
		for x := range cells[y] {
			cells[y][x] = ' '
		}
	}
	return &BufferRenderer{
		width:  width,
		height: height,
		cells:  cells,
	}
}

func (r *BufferRenderer) Size() (int, int) {
	return r.width, r.height
}

func (r *BufferRenderer) Clear() {
	for y := range r.cells {
		for x := range r.cells[y] {
			r.cells[y][x] = ' '
		}
	}
}

func (r *BufferRenderer) SetCell(x, y int, ch rune, _ StyleKind) {
	if y < 0 || y >= r.height || x < 0 || x >= r.width {
		return
	}
	r.cells[y][x] = ch
}

func (r *BufferRenderer) DrawText(x, y int, text string, style StyleKind) {
	for i, ch := range text {
		r.SetCell(x+i, y, ch, style)
	}
}

func (r *BufferRenderer) DrawCentered(y int, text string, style StyleKind) {
	x := max(0, (r.width-len([]rune(text)))/2)
	r.DrawText(x, y, text, style)
}

func (r *BufferRenderer) String() string {
	lines := make([]string, 0, len(r.cells))
	for _, row := range r.cells {
		lines = append(lines, strings.TrimRight(string(row), " "))
	}
	return strings.TrimRight(strings.Join(lines, "\n"), "\n")
}

func tcellStyle(style StyleKind) tcell.Style {
	base := tcell.StyleDefault.Background(tcell.ColorBlack).Foreground(tcell.ColorWhite)
	switch style {
	case StyleTitle:
		return base.Foreground(tcell.ColorBlue).Bold(true)
	case StyleMuted:
		return base.Foreground(tcell.ColorGray)
	case StylePlayer:
		return base.Foreground(tcell.ColorGreen).Bold(true)
	case StyleEnemy:
		return base.Foreground(tcell.ColorMaroon).Bold(true)
	case StyleBoss:
		return base.Foreground(tcell.ColorDarkMagenta).Bold(true)
	case StyleTorch:
		return base.Foreground(tcell.ColorYellow).Bold(true)
	case StyleWall:
		return base.Foreground(tcell.ColorRed).Bold(true)
	case StyleExit:
		return base.Foreground(tcell.ColorAqua).Bold(true)
	case StyleHazard:
		return base.Foreground(tcell.ColorOrange).Bold(true)
	case StyleAccent:
		return base.Foreground(tcell.ColorTeal).Bold(true)
	case StyleSuccess:
		return base.Foreground(tcell.ColorLime).Bold(true)
	case StyleDanger:
		return base.Foreground(tcell.ColorRed).Bold(true)
	default:
		return base
	}
}
