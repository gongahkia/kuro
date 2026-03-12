package game

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/gdamore/tcell/v2"
)

type App struct {
	screen   tcell.Screen
	renderer *TerminalRenderer
	current  Screen
}

func NewApp() (*App, error) {
	screen, err := tcell.NewScreen()
	if err != nil {
		return nil, err
	}
	if err := screen.Init(); err != nil {
		return nil, err
	}
	screen.SetStyle(tcell.StyleDefault.Background(tcell.ColorBlack).Foreground(tcell.ColorWhite))
	screen.Clear()

	app := &App{
		screen:   screen,
		renderer: NewTerminalRenderer(screen),
	}
	app.current = NewTitleScreen(app)
	return app, nil
}

func (a *App) Close() {
	if a.screen != nil {
		a.screen.Fini()
	}
}

func (a *App) Run() error {
	for {
		a.renderer.Clear()
		a.current.Render(a.renderer)
		a.renderer.Show()

		event := a.screen.PollEvent()
		switch ev := event.(type) {
		case *tcell.EventResize:
			a.screen.Sync()
		case *tcell.EventKey:
			input := InputEvent{
				Key:  int(ev.Key()),
				Rune: ev.Rune(),
			}
			transition := a.current.Update(input)
			if transition.Quit {
				return nil
			}
			if transition.Next != nil {
				a.current = transition.Next
			}
		}
	}
}

type TitleScreen struct {
	app      *App
	selected int
	options  []string
}

func NewTitleScreen(app *App) *TitleScreen {
	return &TitleScreen{
		app:      app,
		selected: 0,
		options:  []string{"Start Run", "Help", "Quit"},
	}
}

func (s *TitleScreen) Update(input InputEvent) Transition {
	switch input.Key {
	case int(tcell.KeyUp):
		s.selected = (s.selected - 1 + len(s.options)) % len(s.options)
	case int(tcell.KeyDown):
		s.selected = (s.selected + 1) % len(s.options)
	case int(tcell.KeyEnter):
		return s.selectOption()
	case int(tcell.KeyEscape), int(tcell.KeyCtrlC):
		return Transition{Quit: true}
	}

	switch strings.ToLower(string(input.Rune)) {
	case "w", "k":
		s.selected = (s.selected - 1 + len(s.options)) % len(s.options)
	case "s", "j":
		s.selected = (s.selected + 1) % len(s.options)
	case "\r":
		return s.selectOption()
	case "q":
		return Transition{Quit: true}
	}
	return Transition{}
}

func (s *TitleScreen) selectOption() Transition {
	switch s.selected {
	case 0:
		return Transition{Next: NewDifficultyScreen(s.app)}
	case 1:
		return Transition{Next: NewHelpScreen(s.app)}
	default:
		return Transition{Quit: true}
	}
}

func (s *TitleScreen) Render(renderer Renderer) {
	_, height := renderer.Size()
	renderer.DrawCentered(2, "K U R O", StyleTitle)
	renderer.DrawCentered(4, "Everything is cast in shadow. Something is still hunting you.", StyleAccent)
	renderer.DrawCentered(6, "Collect the torches. Survive three floors. Light the anchors below.", StyleDefault)
	renderer.DrawCentered(8, "s stalker   r rusher   y sentry   l leech   U Umbra", StyleMuted)

	for i, option := range s.options {
		style := StyleDefault
		prefix := "  "
		if i == s.selected {
			style = StyleTorch
			prefix = "> "
		}
		renderer.DrawCentered(11+i, prefix+option, style)
	}

	renderer.DrawCentered(height-3, "[W/S] or arrows to move   [Enter] select   [Q] quit", StyleMuted)
}

type HelpScreen struct {
	app *App
}

func NewHelpScreen(app *App) *HelpScreen {
	return &HelpScreen{app: app}
}

func (s *HelpScreen) Update(input InputEvent) Transition {
	if input.Key == int(tcell.KeyEscape) || input.Key == int(tcell.KeyEnter) || input.Key == int(tcell.KeyCtrlC) {
		return Transition{Next: NewTitleScreen(s.app)}
	}
	switch strings.ToLower(string(input.Rune)) {
	case "q":
		return Transition{Quit: true}
	case "b", "h":
		return Transition{Next: NewTitleScreen(s.app)}
	}
	return Transition{}
}

func (s *HelpScreen) Render(renderer Renderer) {
	renderer.DrawCentered(2, "HOW TO SURVIVE", StyleTitle)
	lines := []string{
		"Move with WASD or the arrow keys. Press '.' to wait a turn.",
		"Floors 1 and 2: recover every torch on the floor, then escape through the exit.",
		"Floor 2 can open into caverns; lore rooms reveal history and sometimes reveal the route ahead.",
		"Floor 3: enter the boss room, collect fire, and light every anchor through Umbra's three phases.",
		"Sentries alarm nearby enemies, leeches dim your light, stalkers patrol, rushers sprint on sight.",
		"Threat rooms can trigger blackouts, gauntlets, shrines, caches, or revelations when entered.",
	}
	for i, line := range lines {
		renderer.DrawCentered(5+i*2, line, StyleDefault)
	}
	renderer.DrawCentered(16, "Press [Enter] or [Esc] to return.", StyleMuted)
}

type DifficultyScreen struct {
	app      *App
	selected int
	options  []Difficulty
}

func NewDifficultyScreen(app *App) *DifficultyScreen {
	return &DifficultyScreen{
		app:      app,
		selected: 0,
		options:  []Difficulty{DifficultyApprentice, DifficultyStalker, DifficultyNightmare},
	}
}

func (s *DifficultyScreen) Update(input InputEvent) Transition {
	switch input.Key {
	case int(tcell.KeyUp):
		s.selected = (s.selected - 1 + len(s.options)) % len(s.options)
	case int(tcell.KeyDown):
		s.selected = (s.selected + 1) % len(s.options)
	case int(tcell.KeyEnter):
		return Transition{Next: NewSeedScreen(s.app, s.options[s.selected])}
	case int(tcell.KeyEscape):
		return Transition{Next: NewTitleScreen(s.app)}
	}
	switch strings.ToLower(string(input.Rune)) {
	case "w":
		s.selected = (s.selected - 1 + len(s.options)) % len(s.options)
	case "s":
		s.selected = (s.selected + 1) % len(s.options)
	case "q":
		return Transition{Quit: true}
	}
	return Transition{}
}

func (s *DifficultyScreen) Render(renderer Renderer) {
	renderer.DrawCentered(2, "DIFFICULTY", StyleTitle)
	renderer.DrawCentered(4, "Scaling changes map size, torch quota, threat budget, and boss aggression.", StyleMuted)
	for i, option := range s.options {
		profile := ProfileForDifficulty(option)
		prefix := "  "
		style := StyleDefault
		if i == s.selected {
			prefix = "> "
			style = StyleTorch
		}
		line := fmt.Sprintf("%s%s  HP:%d  Light:%d  Threat:%d", prefix, option.Label(), profile.PlayerHealth, profile.LightRadius, profile.ThreatBudget)
		renderer.DrawCentered(7+i*2, line, style)
	}
	renderer.DrawCentered(15, "[Enter] choose   [Esc] back", StyleMuted)
}

type SeedScreen struct {
	app        *App
	difficulty Difficulty
	input      string
	err        string
}

func NewSeedScreen(app *App, difficulty Difficulty) *SeedScreen {
	return &SeedScreen{app: app, difficulty: difficulty}
}

func (s *SeedScreen) Update(input InputEvent) Transition {
	switch input.Key {
	case int(tcell.KeyEscape):
		return Transition{Next: NewDifficultyScreen(s.app)}
	case int(tcell.KeyEnter):
		seed := int64(0)
		if s.input != "" {
			parsed, err := strconv.ParseInt(s.input, 10, 64)
			if err != nil {
				s.err = "Seed must be numeric."
				return Transition{}
			}
			seed = parsed
		}
		run, err := NewRun(s.difficulty, seed)
		if err != nil {
			s.err = err.Error()
			return Transition{}
		}
		return Transition{Next: NewPlayingScreen(s.app, run)}
	case int(tcell.KeyBackspace), int(tcell.KeyBackspace2):
		if len(s.input) > 0 {
			s.input = s.input[:len(s.input)-1]
		}
	}

	if input.Rune >= '0' && input.Rune <= '9' {
		s.input += string(input.Rune)
	}
	if input.Rune == '-' && s.input == "" {
		s.input = "-"
	}
	if strings.ToLower(string(input.Rune)) == "q" {
		return Transition{Quit: true}
	}
	return Transition{}
}

func (s *SeedScreen) Render(renderer Renderer) {
	renderer.DrawCentered(2, "RUN SEED", StyleTitle)
	renderer.DrawCentered(4, fmt.Sprintf("Difficulty: %s", s.difficulty.Label()), StyleAccent)
	renderer.DrawCentered(6, "Leave blank for a random seed or type a numeric seed for reproducible levels.", StyleDefault)
	renderer.DrawCentered(9, fmt.Sprintf("> %s", s.input), StyleTorch)
	if s.err != "" {
		renderer.DrawCentered(11, s.err, StyleDanger)
	}
	renderer.DrawCentered(14, "[Enter] begin   [Esc] back", StyleMuted)
}

type PlayingScreen struct {
	app *App
	run *Run
}

func NewPlayingScreen(app *App, run *Run) *PlayingScreen {
	return &PlayingScreen{app: app, run: run}
}

func (s *PlayingScreen) Update(input InputEvent) Transition {
	command := commandFromInput(input)
	if command == CommandNone {
		return Transition{}
	}
	result := s.run.Step(command)
	if result.Quit {
		return Transition{Quit: true}
	}
	if result.Dead {
		return Transition{Next: NewDeathScreen(s.app, s.run)}
	}
	if result.Victory {
		return Transition{Next: NewVictoryScreen(s.app, s.run)}
	}
	return Transition{}
}

func (s *PlayingScreen) Render(renderer Renderer) {
	s.run.Render(renderer)
}

type DeathScreen struct {
	app *App
	run *Run
}

func NewDeathScreen(app *App, run *Run) *DeathScreen {
	return &DeathScreen{app: app, run: run}
}

func (s *DeathScreen) Update(input InputEvent) Transition {
	switch input.Key {
	case int(tcell.KeyEnter), int(tcell.KeyEscape):
		return Transition{Next: NewTitleScreen(s.app)}
	case int(tcell.KeyCtrlC):
		return Transition{Quit: true}
	}
	switch strings.ToLower(string(input.Rune)) {
	case "r":
		return Transition{Next: NewTitleScreen(s.app)}
	case "q":
		return Transition{Quit: true}
	}
	return Transition{}
}

func (s *DeathScreen) Render(renderer Renderer) {
	renderer.DrawCentered(3, "YOU WERE CAUGHT", StyleDanger)
	renderer.DrawCentered(5, fmt.Sprintf("Seed %d  Difficulty %s", s.run.Seed, s.run.Difficulty.Label()), StyleMuted)
	renderer.DrawCentered(7, fmt.Sprintf("Floors cleared: %d", s.run.Stats.FloorsCleared), StyleDefault)
	renderer.DrawCentered(8, fmt.Sprintf("Encounters survived: %d", s.run.Stats.EncountersTriggered), StyleDefault)
	renderer.DrawCentered(9, fmt.Sprintf("Damage taken: %d", s.run.Stats.DamageTaken), StyleDefault)
	renderer.DrawCentered(12, "[Enter/R] title   [Q] quit", StyleMuted)
}

type VictoryScreen struct {
	app *App
	run *Run
}

func NewVictoryScreen(app *App, run *Run) *VictoryScreen {
	return &VictoryScreen{app: app, run: run}
}

func (s *VictoryScreen) Update(input InputEvent) Transition {
	switch input.Key {
	case int(tcell.KeyEnter), int(tcell.KeyEscape):
		return Transition{Next: NewTitleScreen(s.app)}
	case int(tcell.KeyCtrlC):
		return Transition{Quit: true}
	}
	switch strings.ToLower(string(input.Rune)) {
	case "r":
		return Transition{Next: NewTitleScreen(s.app)}
	case "q":
		return Transition{Quit: true}
	}
	return Transition{}
}

func (s *VictoryScreen) Render(renderer Renderer) {
	renderer.DrawCentered(3, "THE DARKNESS BREAKS", StyleSuccess)
	renderer.DrawCentered(5, fmt.Sprintf("Seed %d  Difficulty %s", s.run.Seed, s.run.Difficulty.Label()), StyleMuted)
	renderer.DrawCentered(7, fmt.Sprintf("Floors cleared: %d", max(s.run.Stats.FloorsCleared, s.run.TotalFloors-1)), StyleDefault)
	renderer.DrawCentered(8, fmt.Sprintf("Anchors lit: %d", s.run.Player.BossAnchorsLit), StyleDefault)
	renderer.DrawCentered(9, fmt.Sprintf("Damage taken: %d", s.run.Stats.DamageTaken), StyleDefault)
	renderer.DrawCentered(12, "[Enter/R] title   [Q] quit", StyleMuted)
}

func commandFromInput(input InputEvent) Command {
	switch input.Key {
	case int(tcell.KeyUp):
		return CommandMoveUp
	case int(tcell.KeyRight):
		return CommandMoveRight
	case int(tcell.KeyDown):
		return CommandMoveDown
	case int(tcell.KeyLeft):
		return CommandMoveLeft
	case int(tcell.KeyEscape), int(tcell.KeyCtrlC):
		return CommandQuit
	}
	switch strings.ToLower(string(input.Rune)) {
	case "w", "k":
		return CommandMoveUp
	case "d", "l":
		return CommandMoveRight
	case "s", "j":
		return CommandMoveDown
	case "a", "h":
		return CommandMoveLeft
	case ".", " ":
		return CommandWait
	case "q":
		return CommandQuit
	}
	return CommandNone
}
