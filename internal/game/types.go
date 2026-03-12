package game

import (
	"fmt"
	"math/rand"
)

type Point struct {
	X int
	Y int
}

func (p Point) Add(other Point) Point {
	return Point{X: p.X + other.X, Y: p.Y + other.Y}
}

func (p Point) String() string {
	return fmt.Sprintf("(%d,%d)", p.X, p.Y)
}

var CardinalDirections = []Point{
	{X: 0, Y: -1},
	{X: 1, Y: 0},
	{X: 0, Y: 1},
	{X: -1, Y: 0},
}

type Difficulty int

const (
	DifficultyApprentice Difficulty = iota
	DifficultyStalker
	DifficultyNightmare
)

func (d Difficulty) Label() string {
	switch d {
	case DifficultyApprentice:
		return "Apprentice"
	case DifficultyStalker:
		return "Stalker"
	case DifficultyNightmare:
		return "Nightmare"
	default:
		return "Unknown"
	}
}

type DifficultyProfile struct {
	MapWidth     int
	MapHeight    int
	TorchGoal    int
	ThreatBudget int
	PlayerHealth int
	LightRadius  int
}

func ProfileForDifficulty(d Difficulty) DifficultyProfile {
	switch d {
	case DifficultyApprentice:
		return DifficultyProfile{
			MapWidth:     40,
			MapHeight:    22,
			TorchGoal:    3,
			ThreatBudget: 4,
			PlayerHealth: 7,
			LightRadius:  7,
		}
	case DifficultyNightmare:
		return DifficultyProfile{
			MapWidth:     54,
			MapHeight:    28,
			TorchGoal:    5,
			ThreatBudget: 8,
			PlayerHealth: 4,
			LightRadius:  5,
		}
	default:
		return DifficultyProfile{
			MapWidth:     46,
			MapHeight:    24,
			TorchGoal:    4,
			ThreatBudget: 6,
			PlayerHealth: 5,
			LightRadius:  6,
		}
	}
}

type RunConfig struct {
	Difficulty   Difficulty
	Seed         int64
	Floor        int
	MapWidth     int
	MapHeight    int
	TorchGoal    int
	ThreatBudget int
}

func BuildRunConfig(d Difficulty, seed int64, floor int) RunConfig {
	profile := ProfileForDifficulty(d)
	return RunConfig{
		Difficulty:   d,
		Seed:         seed,
		Floor:        floor,
		MapWidth:     profile.MapWidth + (floor-1)*4,
		MapHeight:    profile.MapHeight + (floor-1)*2,
		TorchGoal:    profile.TorchGoal + max(0, floor-1),
		ThreatBudget: profile.ThreatBudget + (floor-1)*2,
	}
}

type MapArchetype int

const (
	ArchetypeHalls MapArchetype = iota
	ArchetypeCaverns
)

func (a MapArchetype) Label() string {
	switch a {
	case ArchetypeCaverns:
		return "Caverns"
	default:
		return "Halls"
	}
}

type TileKind int

const (
	TileWall TileKind = iota
	TileFloor
	TileExit
	TileTorch
	TileAnchor
	TileShrine
)

type Tile struct {
	Kind TileKind
}

func (t Tile) Glyph() rune {
	switch t.Kind {
	case TileWall:
		return '#'
	case TileExit:
		return '>'
	case TileTorch:
		return '!'
	case TileAnchor:
		return '^'
	case TileShrine:
		return '+'
	default:
		return '.'
	}
}

func (t Tile) BlocksMove() bool {
	return t.Kind == TileWall
}

func (t Tile) BlocksSight() bool {
	return t.Kind == TileWall
}

type RoomTag string

const (
	RoomTagStart     RoomTag = "start"
	RoomTagTorch     RoomTag = "torch"
	RoomTagEncounter RoomTag = "encounter"
	RoomTagSafe      RoomTag = "safe"
	RoomTagBoss      RoomTag = "boss"
	RoomTagExit      RoomTag = "exit"
	RoomTagLore      RoomTag = "lore"
)

type Rect struct {
	X int
	Y int
	W int
	H int
}

func (r Rect) X2() int {
	return r.X + r.W - 1
}

func (r Rect) Y2() int {
	return r.Y + r.H - 1
}

func (r Rect) Center() Point {
	return Point{X: r.X + r.W/2, Y: r.Y + r.H/2}
}

func (r Rect) Contains(p Point) bool {
	return p.X >= r.X && p.X <= r.X2() && p.Y >= r.Y && p.Y <= r.Y2()
}

type Room struct {
	ID     int
	Rect   Rect
	Center Point
	Cells  []Point
	Tags   map[RoomTag]bool
}

func (r Room) Has(tag RoomTag) bool {
	return r.Tags[tag]
}

type EnemyKind int

const (
	EnemyStalker EnemyKind = iota
	EnemyRusher
	EnemySentry
	EnemyLeech
	EnemyBoss
)

func (k EnemyKind) String() string {
	switch k {
	case EnemyStalker:
		return "Stalker"
	case EnemyRusher:
		return "Rusher"
	case EnemySentry:
		return "Sentry"
	case EnemyLeech:
		return "Leech"
	case EnemyBoss:
		return "Umbra"
	default:
		return "Unknown"
	}
}

func (k EnemyKind) Glyph() rune {
	switch k {
	case EnemyStalker:
		return 's'
	case EnemyRusher:
		return 'r'
	case EnemySentry:
		return 'y'
	case EnemyLeech:
		return 'l'
	case EnemyBoss:
		return 'U'
	default:
		return '?'
	}
}

type EnemyState string

const (
	EnemyStateIdle    EnemyState = "idle"
	EnemyStateSearch  EnemyState = "search"
	EnemyStateChase   EnemyState = "chase"
	EnemyStateRetreat EnemyState = "retreat"
)

type Enemy struct {
	ID           int
	Kind         EnemyKind
	Pos          Point
	Home         Point
	Patrol       Point
	State        EnemyState
	Facing       Point
	LastSeen     Point
	AlertTurns   int
	RetreatTurns int
	StunTurns    int
	SearchTurns  int
	Cooldown     int
}

type Player struct {
	Pos            Point
	Health         int
	MaxHealth      int
	BaseLight      int
	Torches        int
	TorchGoal      int
	Collected      int
	DimmedTurns    int
	Steps          int
	BossAnchorsLit int
}

func (p Player) LightRadius() int {
	light := p.BaseLight + min(2, p.Torches)
	if p.DimmedTurns > 0 {
		light -= 2
	}
	return max(3, light)
}

type EncounterType string

const (
	EncounterAmbush     EncounterType = "ambush"
	EncounterEliteHunt  EncounterType = "elite-hunt"
	EncounterTrap       EncounterType = "trap"
	EncounterTorch      EncounterType = "torch-cache"
	EncounterShrine     EncounterType = "shrine"
	EncounterBlackout   EncounterType = "blackout"
	EncounterLore       EncounterType = "lore"
	EncounterGauntlet   EncounterType = "gauntlet"
	EncounterRevelation EncounterType = "revelation"
)

type Director struct {
	ThreatRemaining int
	Cooldown        int
	TriggeredRooms  map[int]bool
	LastEncounter   EncounterType
	ThreatStreak    int
	MercyCounter    int
	LoreIndex       int
}

type BossFight struct {
	Active         bool
	RoomID         int
	Anchors        map[Point]bool
	Telegraphs     map[Point]int
	Hazards        map[Point]int
	Phase          int
	PhaseTurns     int
	Fractures      int
	PulseCooldown  int
	SummonCooldown int
	WallCooldown   int
}

type Level struct {
	Width           int
	Height          int
	Archetype       MapArchetype
	Tiles           [][]Tile
	Rooms           []Room
	Spawn           Point
	Exit            Point
	TorchSpawns     []Point
	EncounterSpawns []Point
	EnemySpawns     []Enemy
	BossRoomID      int
	RoomIndex       map[Point]int
}

type ActionKind int

const (
	ActionWait ActionKind = iota
	ActionMove
	ActionAttack
	ActionAlarm
	ActionDim
)

type Action struct {
	Kind   ActionKind
	Target Point
	Power  int
}

type ActorState struct {
	Self        Enemy
	Player      Player
	AlarmActive bool
	Turn        int
}

type EnemyAI interface {
	NextAction(LevelView, ActorState) Action
}

type LevelView struct {
	Level              *Level
	Occupied           map[Point]bool
	DistanceToPlayer   map[Point]int
	DistanceFromPlayer map[Point]int
	VisibleToPlayer    map[Point]bool
}

type Transition struct {
	Next Screen
	Quit bool
}

type InputEvent struct {
	Key  int
	Rune rune
}

type Command int

const (
	CommandNone Command = iota
	CommandMoveUp
	CommandMoveRight
	CommandMoveDown
	CommandMoveLeft
	CommandWait
	CommandQuit
)

type Screen interface {
	Update(InputEvent) Transition
	Render(Renderer)
}

type Generator interface {
	Generate(RunConfig, *rand.Rand) (Level, error)
}

type RunStats struct {
	FloorsCleared       int
	EncountersTriggered int
	DamageTaken         int
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func abs(v int) int {
	if v < 0 {
		return -v
	}
	return v
}
