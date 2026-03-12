package game

import (
	"fmt"
	"math/rand"
	"sort"
	"strings"
	"time"
)

type StepResult struct {
	Quit      bool
	Dead      bool
	Victory   bool
	FloorNext bool
}

type Run struct {
	Seed        int64
	Difficulty  Difficulty
	Generator   Generator
	RNG         *rand.Rand
	Config      RunConfig
	TotalFloors int
	Floor       int

	Player      Player
	Level       Level
	Enemies     []Enemy
	Director    Director
	Boss        BossFight
	Visible     map[Point]bool
	Explored    map[Point]bool
	Messages    []string
	AlarmTurns  int
	CurrentRoom int
	Stats       RunStats
	Dead        bool
	Victory     bool
}

func NewRun(difficulty Difficulty, seed int64) (*Run, error) {
	if seed == 0 {
		seed = time.Now().UnixNano()
	}
	run := &Run{
		Seed:        seed,
		Difficulty:  difficulty,
		Generator:   NewHybridGenerator(),
		RNG:         rand.New(rand.NewSource(seed)),
		TotalFloors: 3,
		Messages:    []string{},
	}
	profile := ProfileForDifficulty(difficulty)
	run.Player = Player{
		Health:    profile.PlayerHealth,
		MaxHealth: profile.PlayerHealth,
		BaseLight: profile.LightRadius,
	}
	if err := run.loadFloor(1); err != nil {
		return nil, err
	}
	return run, nil
}

func (r *Run) loadFloor(floor int) error {
	cfg := BuildRunConfig(r.Difficulty, r.Seed, floor)
	floorRNG := rand.New(rand.NewSource(r.Seed + int64(floor*7919)))
	level, err := r.Generator.Generate(cfg, floorRNG)
	if err != nil {
		return err
	}

	r.Config = cfg
	r.Floor = floor
	r.Level = level
	r.Player.Pos = level.Spawn
	r.Player.TorchGoal = cfg.TorchGoal
	r.Player.Torches = 0
	r.Player.Collected = 0
	r.Player.DimmedTurns = 0
	r.Player.BossAnchorsLit = 0
	r.CurrentRoom = -1
	r.AlarmTurns = 0
	r.Enemies = append([]Enemy(nil), level.EnemySpawns...)
	r.Director = Director{
		ThreatRemaining: cfg.ThreatBudget + 1,
		TriggeredRooms:  map[int]bool{},
	}
	r.Boss = BossFight{
		RoomID:         level.BossRoomID,
		Anchors:        map[Point]bool{},
		Telegraphs:     map[Point]int{},
		Hazards:        map[Point]int{},
		Phase:          1,
		PulseCooldown:  3,
		SummonCooldown: 2,
		WallCooldown:   3,
	}
	for y := 0; y < level.Height; y++ {
		for x := 0; x < level.Width; x++ {
			p := Point{X: x, Y: y}
			if level.TileAt(p).Kind == TileAnchor {
				r.Boss.Anchors[p] = false
			}
		}
	}
	r.Visible = map[Point]bool{}
	r.Explored = map[Point]bool{}
	r.pushMessage(fmt.Sprintf("Floor %d / %d: descend into the %s.", floor, r.TotalFloors, strings.ToLower(level.Archetype.Label())))
	if floor == r.TotalFloors {
		r.pushMessage("The final chamber breathes. Light the anchors and survive Umbra.")
	}
	r.refreshVision()
	return nil
}

func (r *Run) Step(command Command) StepResult {
	result := StepResult{}
	if r.Dead || r.Victory {
		result.Dead = r.Dead
		result.Victory = r.Victory
		return result
	}
	if command == CommandQuit {
		result.Quit = true
		return result
	}

	playerMoved := false
	switch command {
	case CommandMoveUp:
		playerMoved = r.tryMovePlayer(CardinalDirections[0])
	case CommandMoveRight:
		playerMoved = r.tryMovePlayer(CardinalDirections[1])
	case CommandMoveDown:
		playerMoved = r.tryMovePlayer(CardinalDirections[2])
	case CommandMoveLeft:
		playerMoved = r.tryMovePlayer(CardinalDirections[3])
	case CommandWait:
		playerMoved = true
	default:
		return result
	}

	if !playerMoved {
		r.refreshVision()
		return result
	}

	r.Player.Steps++
	r.resolvePlayerTile()
	if r.Dead || r.Victory {
		r.refreshVision()
		result.Dead = r.Dead
		result.Victory = r.Victory
		return result
	}

	if r.tryAdvanceFloor() {
		result.FloorNext = true
		return result
	}

	r.triggerRoomEncounter()
	r.advanceEnemies()
	r.advanceBoss()
	r.tickHazards()
	r.endTurn()
	r.refreshVision()

	result.Dead = r.Dead
	result.Victory = r.Victory
	return result
}

func (r *Run) tryMovePlayer(direction Point) bool {
	target := r.Player.Pos.Add(direction)
	if !r.Level.IsWalkable(target) {
		r.pushMessage("Stone answers your step.")
		return false
	}
	if _, ok := r.enemyIndexAt(target); ok {
		r.pushMessage("Something blocks the path.")
		return false
	}
	r.Player.Pos = target
	return true
}

func (r *Run) resolvePlayerTile() {
	tile := r.Level.TileAt(r.Player.Pos)
	switch tile.Kind {
	case TileTorch:
		r.Player.Torches++
		r.Player.Collected++
		r.Level.SetTile(r.Player.Pos, TileFloor)
		r.pushMessage(fmt.Sprintf("Torch claimed %d / %d.", r.Player.Collected, r.Player.TorchGoal))
	case TileShrine:
		if r.Player.Health < r.Player.MaxHealth {
			r.Player.Health++
		}
		r.Player.DimmedTurns = 0
		r.Level.SetTile(r.Player.Pos, TileFloor)
		r.pushMessage("A shrine steadies your nerves and brightens the flame.")
	case TileAnchor:
		if !r.Boss.Anchors[r.Player.Pos] {
			if r.Player.Torches > 0 {
				r.Player.Torches--
				r.Boss.Anchors[r.Player.Pos] = true
				r.Player.BossAnchorsLit++
				r.pushMessage(fmt.Sprintf("Anchor lit %d / %d.", r.Player.BossAnchorsLit, len(r.Boss.Anchors)))
				if r.Player.BossAnchorsLit == len(r.Boss.Anchors) {
					r.Victory = true
					r.pushMessage("Umbra buckles under the light. You survive the abyss.")
				}
			} else {
				r.pushMessage("The anchor rejects empty hands. Bring it fire.")
			}
		}
	}
}

func (r *Run) tryAdvanceFloor() bool {
	if r.Floor >= r.TotalFloors {
		return false
	}
	if r.Player.Pos != r.Level.Exit {
		return false
	}
	if r.Player.Collected < r.Player.TorchGoal {
		r.pushMessage("The stairwell stays sealed. More torches remain.")
		return false
	}
	r.Stats.FloorsCleared++
	nextFloor := r.Floor + 1
	r.pushMessage(fmt.Sprintf("The exit yields. Floor %d awaits.", nextFloor))
	if err := r.loadFloor(nextFloor); err != nil {
		r.Dead = true
		r.pushMessage("The descent collapses into static and stone.")
	}
	return true
}

func (r *Run) triggerRoomEncounter() {
	room, roomIndex, ok := r.Level.RoomAt(r.Player.Pos)
	if !ok {
		r.CurrentRoom = -1
		return
	}
	if roomIndex == r.CurrentRoom {
		return
	}
	r.CurrentRoom = roomIndex
	if room.Has(RoomTagBoss) && !r.Boss.Active {
		r.Boss.Active = true
		r.pushMessage("Umbra wakes. The room begins to pulse.")
	}
	if room.Has(RoomTagLore) && !r.Director.TriggeredRooms[-(roomIndex+1)] {
		r.Director.TriggeredRooms[-(roomIndex + 1)] = true
		r.emitLore(roomIndex)
	}
	if !room.Has(RoomTagEncounter) {
		return
	}
	if r.Director.TriggeredRooms[roomIndex] {
		return
	}
	r.Director.TriggeredRooms[roomIndex] = true
	r.Stats.EncountersTriggered++
	if r.Director.Cooldown > 0 {
		r.Director.Cooldown--
		r.pushMessage("The room tenses, but the dark holds back.")
		return
	}
	encounter := r.pickEncounter()
	r.applyEncounter(room, encounter)
}

func (r *Run) pickEncounter() EncounterType {
	threatful := []EncounterType{EncounterAmbush, EncounterEliteHunt, EncounterTrap}
	if r.Floor >= 2 {
		threatful = append(threatful, EncounterBlackout, EncounterGauntlet)
	}
	beneficial := []EncounterType{EncounterTorch, EncounterShrine, EncounterRevelation}
	if r.Director.LoreIndex < len(loreFragments) {
		beneficial = append(beneficial, EncounterLore)
	}
	if r.Director.ThreatRemaining <= 0 || r.Director.MercyCounter >= 2 || r.Director.ThreatStreak >= 2 {
		choice := beneficial[r.RNG.Intn(len(beneficial))]
		r.Director.LastEncounter = choice
		r.Director.ThreatStreak = 0
		r.Director.MercyCounter = 0
		r.Director.Cooldown = 1
		return choice
	}
	pool := append([]EncounterType{}, threatful...)
	if r.Level.Archetype == ArchetypeCaverns {
		pool = append(pool, EncounterBlackout)
	}
	if r.RNG.Intn(3) == 0 {
		pool = append(pool, beneficial...)
	}
	choice := pool[r.RNG.Intn(len(pool))]
	if choice == r.Director.LastEncounter && len(pool) > 1 {
		choice = pool[(r.RNG.Intn(len(pool)-1)+1)%len(pool)]
	}
	switch choice {
	case EncounterTorch, EncounterShrine, EncounterLore, EncounterRevelation:
		r.Director.ThreatStreak = 0
		r.Director.MercyCounter = 0
		r.Director.Cooldown = 1
	default:
		r.Director.ThreatRemaining--
		r.Director.ThreatStreak++
		r.Director.MercyCounter++
		r.Director.Cooldown = 2
	}
	r.Director.LastEncounter = choice
	return choice
}

func (r *Run) applyEncounter(room Room, encounter EncounterType) {
	switch encounter {
	case EncounterAmbush:
		if r.spawnEnemyInRoom(room, EnemyStalker) {
			r.spawnEnemyInRoom(room, EnemyLeech)
		}
		r.pushMessage("An ambush peels itself out of the walls.")
	case EncounterEliteHunt:
		if r.spawnEnemyInRoom(room, EnemyRusher) {
			r.pushMessage("A rusher screams down the corridor.")
		}
	case EncounterTrap:
		cells := r.roomCells(room)
		r.RNG.Shuffle(len(cells), func(i, j int) {
			cells[i], cells[j] = cells[j], cells[i]
		})
		for i := 0; i < min(4, len(cells)); i++ {
			r.Boss.Telegraphs[cells[i]] = 2
		}
		r.pushMessage("The floor itself starts whispering a pattern of harm.")
	case EncounterTorch:
		r.Player.Torches++
		r.pushMessage("A cache of fire buys you a little courage.")
	case EncounterShrine:
		r.Player.Health = min(r.Player.MaxHealth, r.Player.Health+2)
		r.Player.DimmedTurns = 0
		r.pushMessage("A shrine settles the panic in your chest.")
	case EncounterBlackout:
		r.Player.DimmedTurns = max(r.Player.DimmedTurns, 5)
		r.spawnEnemyInRoom(room, EnemySentry)
		r.spawnEnemyInRoom(room, EnemyLeech)
		r.pushMessage("The room gutters into a deeper black and watchers take shape.")
	case EncounterLore:
		r.emitLore(room.ID)
		r.Player.Health = min(r.Player.MaxHealth, r.Player.Health+1)
	case EncounterGauntlet:
		r.spawnEnemyInRoom(room, EnemyStalker)
		r.spawnEnemyInRoom(room, EnemyRusher)
		r.spawnEnemyInRoom(room, EnemySentry)
		r.pushMessage("A hunting chorus answers your footsteps.")
	case EncounterRevelation:
		r.revealObjectivePath()
		r.pushMessage("The torchlight bends and briefly shows a safer route.")
	}
}

func (r *Run) advanceEnemies() {
	occupied := r.occupied()
	playerFlow := BuildDistanceMap(r.Level, []Point{r.Player.Pos}, nil)
	darknessFlow := BuildDarknessMap(r.Level, r.Visible, occupied)
	for i := range r.Enemies {
		enemy := r.Enemies[i]
		if enemy.Kind == EnemyBoss && !r.Boss.Active {
			continue
		}
		enemy = r.prepareEnemy(enemy)
		if enemy.Cooldown > 0 {
			enemy.Cooldown--
			r.Enemies[i] = enemy
			continue
		}
		action := aiForKind(enemy.Kind).NextAction(LevelView{
			Level:              &r.Level,
			Occupied:           occupied,
			DistanceToPlayer:   playerFlow,
			DistanceFromPlayer: darknessFlow,
			VisibleToPlayer:    r.Visible,
		}, ActorState{
			Self:        enemy,
			Player:      r.Player,
			AlarmActive: r.AlarmTurns > 0,
			Turn:        r.Player.Steps,
		})

		switch action.Kind {
		case ActionAttack:
			r.damagePlayer(action.Power, fmt.Sprintf("%s tears into you.", enemy.Kind.String()))
			if enemy.Kind == EnemyLeech {
				r.Player.DimmedTurns = max(r.Player.DimmedTurns, 3)
				enemy.RetreatTurns = 2
			}
		case ActionDim:
			r.damagePlayer(1, "A leech strips heat from your torch.")
			r.Player.DimmedTurns = max(r.Player.DimmedTurns, 4)
			enemy.RetreatTurns = 2
		case ActionAlarm:
			r.AlarmTurns = max(r.AlarmTurns, action.Power)
			r.pushMessage("A sentry shrieks. Everything nearby hears it.")
			for j := range r.Enemies {
				if r.Enemies[j].Kind != EnemyBoss {
					r.Enemies[j].AlertTurns = max(r.Enemies[j].AlertTurns, 3)
					r.Enemies[j].LastSeen = r.Player.Pos
				}
			}
			enemy.Facing = facingTowards(enemy.Pos, r.Player.Pos)
		case ActionMove:
			if action.Target == r.Player.Pos {
				r.damagePlayer(max(1, action.Power), fmt.Sprintf("%s crashes into you.", enemy.Kind.String()))
			} else if r.Level.IsWalkable(action.Target) && !occupied[action.Target] {
				delete(occupied, enemy.Pos)
				enemy.Pos = action.Target
				occupied[enemy.Pos] = true
				if enemy.Kind == EnemySentry {
					enemy.Facing = facingTowards(enemy.Pos, r.Player.Pos)
				} else if enemy.Pos != r.Player.Pos {
					enemy.Facing = facingTowards(enemy.Pos, r.Player.Pos)
				}
				if enemy.Pos == enemy.Patrol && enemy.Patrol != enemy.Home {
					enemy.Patrol, enemy.Home = enemy.Home, enemy.Patrol
				}
			}
		default:
			if enemy.Kind == EnemySentry {
				enemy.Facing = rotateClockwise(enemy.Facing)
			}
		}

		if enemy.AlertTurns > 0 {
			enemy.AlertTurns--
		}
		if enemy.RetreatTurns > 0 {
			enemy.RetreatTurns--
		}
		if enemy.SearchTurns > 0 && enemy.State != EnemyStateChase {
			enemy.SearchTurns--
		}
		r.Enemies[i] = enemy
	}
}

func (r *Run) advanceBoss() {
	if !r.Boss.Active || r.Victory || r.Dead {
		return
	}
	r.updateBossPhase()
	r.Boss.PhaseTurns++
	if r.Boss.PulseCooldown > 0 {
		r.Boss.PulseCooldown--
	}
	if r.Boss.SummonCooldown > 0 {
		r.Boss.SummonCooldown--
	}
	if r.Boss.WallCooldown > 0 {
		r.Boss.WallCooldown--
	}

	if r.Boss.PulseCooldown == 0 {
		r.Player.DimmedTurns = max(r.Player.DimmedTurns, 2+r.Boss.Phase)
		for _, point := range bossTelegraphPattern(r) {
			if r.Level.IsWalkable(point) {
				r.Boss.Telegraphs[point] = 2
			}
		}
		r.Boss.PulseCooldown = max(1, 4-r.Boss.Phase)
		r.pushMessage(bossPhaseMessage(r.Boss.Phase))
	}
	if r.Boss.WallCooldown == 0 && r.Boss.Phase >= 2 {
		for _, point := range bossWallPattern(r) {
			if r.Level.IsWalkable(point) {
				r.Boss.Telegraphs[point] = 2
			}
		}
		r.Boss.WallCooldown = max(2, 5-r.Boss.Phase)
	}
	if r.Boss.SummonCooldown == 0 {
		r.spawnBossAdds()
		r.Boss.SummonCooldown = max(1, 4-r.Boss.Phase)
	}
}

func (r *Run) tickHazards() {
	points := make([]Point, 0, len(r.Boss.Telegraphs))
	for point := range r.Boss.Telegraphs {
		points = append(points, point)
	}
	sort.Slice(points, func(i, j int) bool {
		if points[i].Y == points[j].Y {
			return points[i].X < points[j].X
		}
		return points[i].Y < points[j].Y
	})
	for _, point := range points {
		timer := r.Boss.Telegraphs[point] - 1
		if timer <= 0 {
			delete(r.Boss.Telegraphs, point)
			r.Boss.Hazards[point] = max(1, r.Boss.Phase-1)
		} else {
			r.Boss.Telegraphs[point] = timer
		}
	}

	for point, timer := range r.Boss.Hazards {
		if point == r.Player.Pos {
			r.damagePlayer(1, "The marked ground erupts under your feet.")
		}
		if timer <= 1 {
			delete(r.Boss.Hazards, point)
		} else {
			r.Boss.Hazards[point] = timer - 1
		}
	}
}

func (r *Run) endTurn() {
	if r.Player.DimmedTurns > 0 {
		r.Player.DimmedTurns--
	}
	if r.AlarmTurns > 0 {
		r.AlarmTurns--
	}
	if r.Player.Health <= 0 {
		r.Dead = true
	}
}

func (r *Run) refreshVision() {
	r.Visible = ComputeFOV(r.Level, r.Player.Pos, r.Player.LightRadius())
	for point := range r.Visible {
		r.Explored[point] = true
	}
}

func (r *Run) Render(renderer Renderer) {
	renderer.Clear()
	width, height := renderer.Size()
	mapTop := 2
	hudLines := 6
	mapHeight := max(10, height-mapTop-hudLines)
	mapWidth := max(20, width-2)
	startX := clamp(r.Player.Pos.X-mapWidth/2, 0, max(0, r.Level.Width-mapWidth))
	startY := clamp(r.Player.Pos.Y-mapHeight/2, 0, max(0, r.Level.Height-mapHeight))

	renderer.DrawText(1, 0, fmt.Sprintf("KURO v2  Floor %d/%d  %s  %s  Seed %d", r.Floor, r.TotalFloors, r.Difficulty.Label(), r.Level.Archetype.Label(), r.Seed), StyleTitle)
	renderer.DrawText(1, 1, fmt.Sprintf("HP %d/%d  Torches %d  Goal %d/%d  Light %d  Phase %d", r.Player.Health, r.Player.MaxHealth, r.Player.Torches, r.Player.Collected, r.Player.TorchGoal, r.Player.LightRadius(), max(1, r.Boss.Phase)), StyleAccent)

	for y := 0; y < mapHeight; y++ {
		for x := 0; x < mapWidth; x++ {
			point := Point{X: startX + x, Y: startY + y}
			screenX := x + 1
			screenY := y + mapTop
			ch, style := r.cellFor(point)
			renderer.SetCell(screenX, screenY, ch, style)
		}
	}

	baseY := mapTop + mapHeight + 1
	renderer.DrawText(1, baseY, "[WASD / Arrows] Move  [.] Wait  [Q] Quit", StyleMuted)
	renderer.DrawText(1, baseY+1, r.objectiveLine(), StyleDefault)
	messageStart := max(0, len(r.Messages)-3)
	for i, message := range r.Messages[messageStart:] {
		renderer.DrawText(1, baseY+2+i, message, StyleMuted)
	}
}

func (r *Run) cellFor(point Point) (rune, StyleKind) {
	if point == r.Player.Pos {
		return '@', StylePlayer
	}
	if !r.Explored[point] {
		return ' ', StyleDefault
	}

	for _, enemy := range r.Enemies {
		if enemy.Pos == point && r.Visible[point] {
			if enemy.Kind == EnemyBoss {
				return enemy.Kind.Glyph(), StyleBoss
			}
			return enemy.Kind.Glyph(), StyleEnemy
		}
	}

	if r.Boss.Hazards[point] > 0 && r.Visible[point] {
		return '*', StyleHazard
	}
	if r.Boss.Telegraphs[point] > 0 && r.Visible[point] {
		return 'x', StyleDanger
	}

	tile := r.Level.TileAt(point)
	if !r.Visible[point] {
		switch tile.Kind {
		case TileWall:
			return '#', StyleMuted
		case TileExit:
			return '>', StyleMuted
		case TileAnchor:
			if r.Boss.Anchors[point] {
				return '^', StyleSuccess
			}
			return '^', StyleMuted
		default:
			return '.', StyleMuted
		}
	}

	switch tile.Kind {
	case TileWall:
		return tile.Glyph(), StyleWall
	case TileExit:
		return tile.Glyph(), StyleExit
	case TileTorch:
		return tile.Glyph(), StyleTorch
	case TileAnchor:
		if r.Boss.Anchors[point] {
			return tile.Glyph(), StyleSuccess
		}
		return tile.Glyph(), StyleTorch
	case TileShrine:
		return tile.Glyph(), StyleSuccess
	default:
		return ' ', StyleDefault
	}
}

func (r *Run) objectiveLine() string {
	if r.Floor == r.TotalFloors {
		return fmt.Sprintf("Objective: carry fire to %d anchors and stay alive.", len(r.Boss.Anchors))
	}
	if r.Player.Collected < r.Player.TorchGoal {
		return fmt.Sprintf("Objective: recover %d more torches before the exit opens.", r.Player.TorchGoal-r.Player.Collected)
	}
	return "Objective: reach the exit before the dark closes again."
}

func (r *Run) pushMessage(message string) {
	r.Messages = append(r.Messages, message)
	if len(r.Messages) > 8 {
		r.Messages = r.Messages[len(r.Messages)-8:]
	}
}

func (r *Run) damagePlayer(amount int, reason string) {
	r.Player.Health -= amount
	r.Stats.DamageTaken += amount
	r.pushMessage(reason)
	if r.Player.Health <= 0 {
		r.Player.Health = 0
		r.Dead = true
		r.pushMessage("Your body finally yields to the corridor.")
	}
}

func (r *Run) occupied() map[Point]bool {
	occupied := map[Point]bool{}
	for _, enemy := range r.Enemies {
		if enemy.Kind == EnemyBoss && !r.Boss.Active {
			continue
		}
		occupied[enemy.Pos] = true
	}
	return occupied
}

func (r *Run) enemyIndexAt(point Point) (int, bool) {
	for i, enemy := range r.Enemies {
		if enemy.Pos == point && (enemy.Kind != EnemyBoss || r.Boss.Active) {
			return i, true
		}
	}
	return -1, false
}

func (r *Run) spawnEnemyInRoom(room Room, kind EnemyKind) bool {
	reserved := r.occupied()
	reserved[r.Player.Pos] = true
	for _, point := range r.roomCells(room) {
		if reserved[point] {
			continue
		}
		if manhattan(point, r.Player.Pos) <= 1 {
			continue
		}
		r.Enemies = append(r.Enemies, Enemy{
			ID:          len(r.Enemies) + 1,
			Kind:        kind,
			Pos:         point,
			Home:        room.Center,
			Patrol:      randomPointInRoom(r.Level, room, r.RNG, map[Point]bool{point: true}),
			State:       EnemyStateSearch,
			Facing:      facingTowards(point, r.Player.Pos),
			LastSeen:    r.Player.Pos,
			AlertTurns:  2,
			SearchTurns: 3,
		})
		return true
	}
	return false
}

func (r *Run) roomCells(room Room) []Point {
	cells := append([]Point{}, room.Cells...)
	if len(cells) == 0 {
		for y := room.Rect.Y; y <= room.Rect.Y2(); y++ {
			for x := room.Rect.X; x <= room.Rect.X2(); x++ {
				point := Point{X: x, Y: y}
				if r.Level.IsWalkable(point) {
					cells = append(cells, point)
				}
			}
		}
	}
	r.RNG.Shuffle(len(cells), func(i, j int) {
		cells[i], cells[j] = cells[j], cells[i]
	})
	return cells
}

func (r *Run) prepareEnemy(enemy Enemy) Enemy {
	playerVisible := enemyCanSeePlayer(r.Level, enemy, r.Player)
	switch {
	case enemy.Kind == EnemyLeech && enemy.RetreatTurns > 0:
		enemy.State = EnemyStateRetreat
	case playerVisible:
		enemy.State = EnemyStateChase
		enemy.LastSeen = r.Player.Pos
		enemy.SearchTurns = max(enemy.SearchTurns, 4)
		enemy.AlertTurns = max(enemy.AlertTurns, 3)
	case enemy.AlertTurns > 0 || r.AlarmTurns > 0:
		enemy.State = EnemyStateSearch
		if enemy.LastSeen == (Point{}) {
			enemy.LastSeen = r.Player.Pos
		}
		enemy.SearchTurns = max(enemy.SearchTurns, 2)
	case enemy.SearchTurns > 0:
		enemy.State = EnemyStateSearch
	default:
		enemy.State = EnemyStateIdle
	}
	return enemy
}

var loreFragments = []string{
	"The walls remember names the same way bones remember weight.",
	"A torch can wound Umbra, but only if the light is offered, not hoarded.",
	"The sentries were once pilgrims who looked too long into the pit.",
	"The black water under the caverns reflects a ceiling that does not exist.",
	"Every shrine marks a place where someone almost escaped.",
}

func (r *Run) emitLore(roomIndex int) {
	message := loreFragments[r.Director.LoreIndex%len(loreFragments)]
	r.Director.LoreIndex++
	r.pushMessage(fmt.Sprintf("Lore %d: %s", r.Director.LoreIndex, message))
	if roomIndex >= 0 {
		r.pushMessage("The room answers with a colder echo than before.")
	}
}

func (r *Run) revealObjectivePath() {
	target, ok := r.currentObjectiveTarget()
	if !ok {
		return
	}
	path := FindPath(r.Level, r.Player.Pos, target, nil)
	for _, point := range path {
		r.Explored[point] = true
	}
}

func (r *Run) currentObjectiveTarget() (Point, bool) {
	if r.Floor < r.TotalFloors {
		if target, ok := nearestTile(r.Level, r.Player.Pos, TileTorch); ok {
			return target, true
		}
		if r.Level.InBounds(r.Level.Exit) {
			return r.Level.Exit, true
		}
		return Point{}, false
	}
	if target, ok := nearestTile(r.Level, r.Player.Pos, TileTorch); ok {
		return target, true
	}
	for point, lit := range r.Boss.Anchors {
		if !lit {
			return point, true
		}
	}
	return Point{}, false
}

func (r *Run) updateBossPhase() {
	newPhase := 1
	switch {
	case r.Player.BossAnchorsLit >= max(2, len(r.Boss.Anchors)-1):
		newPhase = 3
	case r.Player.BossAnchorsLit >= 1:
		newPhase = 2
	}
	if newPhase != r.Boss.Phase {
		r.Boss.Phase = newPhase
		r.Boss.PhaseTurns = 0
		r.pushMessage(fmt.Sprintf("Umbra shifts into phase %d.", newPhase))
	}
}

func (r *Run) spawnBossAdds() {
	room, _, ok := r.Level.RoomAt(r.Player.Pos)
	if !ok {
		return
	}
	switch r.Boss.Phase {
	case 1:
		r.spawnEnemyInRoom(room, EnemyStalker)
		r.pushMessage("Shadows congeal into a fresh stalker.")
	case 2:
		r.spawnEnemyInRoom(room, EnemySentry)
		r.spawnEnemyInRoom(room, EnemyLeech)
		r.pushMessage("Umbra seeds the chamber with watchers and leeches.")
	default:
		r.spawnEnemyInRoom(room, EnemyRusher)
		r.spawnEnemyInRoom(room, EnemyLeech)
		r.pushMessage("Umbra fractures and flings its faster hunters at you.")
	}
}

func bossTelegraphPattern(run *Run) []Point {
	points := []Point{}
	switch run.Boss.Phase {
	case 1:
		points = append(points, run.Player.Pos, run.Player.Pos.Add(Point{X: 1, Y: 0}), run.Player.Pos.Add(Point{X: -1, Y: 0}), run.Player.Pos.Add(Point{X: 0, Y: 1}), run.Player.Pos.Add(Point{X: 0, Y: -1}))
	case 2:
		for _, dir := range CardinalDirections {
			points = append(points, run.Player.Pos.Add(dir), run.Player.Pos.Add(Point{X: dir.X * 2, Y: dir.Y * 2}))
		}
	case 3:
		for dx := -2; dx <= 2; dx++ {
			points = append(points, run.Player.Pos.Add(Point{X: dx, Y: 0}))
		}
		for dy := -2; dy <= 2; dy++ {
			points = append(points, run.Player.Pos.Add(Point{X: 0, Y: dy}))
		}
	}
	return uniquePoints(points)
}

func bossWallPattern(run *Run) []Point {
	room, _, ok := run.Level.RoomAt(run.Player.Pos)
	if !ok {
		return nil
	}
	points := []Point{}
	if run.Boss.Phase == 2 {
		for x := room.Rect.X; x <= room.Rect.X2(); x++ {
			points = append(points, Point{X: x, Y: run.Player.Pos.Y})
		}
		return uniquePoints(points)
	}
	for y := room.Rect.Y; y <= room.Rect.Y2(); y++ {
		points = append(points, Point{X: run.Player.Pos.X, Y: y})
	}
	return uniquePoints(points)
}

func bossPhaseMessage(phase int) string {
	switch phase {
	case 2:
		return "Umbra exhales and the chamber folds into a harsher geometry."
	case 3:
		return "Umbra tears the room open. The dark attacks from every angle."
	default:
		return "Umbra exhales and the room darkens around you."
	}
}

func uniquePoints(points []Point) []Point {
	seen := map[Point]bool{}
	unique := make([]Point, 0, len(points))
	for _, point := range points {
		if seen[point] {
			continue
		}
		seen[point] = true
		unique = append(unique, point)
	}
	return unique
}

func nearestTile(level Level, origin Point, kind TileKind) (Point, bool) {
	best := Point{}
	bestDistance := 1 << 30
	for y := 0; y < level.Height; y++ {
		for x := 0; x < level.Width; x++ {
			point := Point{X: x, Y: y}
			if level.TileAt(point).Kind != kind {
				continue
			}
			dist := manhattan(origin, point)
			if dist < bestDistance {
				bestDistance = dist
				best = point
			}
		}
	}
	if bestDistance == 1<<30 {
		return Point{}, false
	}
	return best, true
}

func rotateClockwise(direction Point) Point {
	switch direction {
	case Point{X: 0, Y: -1}:
		return Point{X: 1, Y: 0}
	case Point{X: 1, Y: 0}:
		return Point{X: 0, Y: 1}
	case Point{X: 0, Y: 1}:
		return Point{X: -1, Y: 0}
	default:
		return Point{X: 0, Y: -1}
	}
}

func facingTowards(from, to Point) Point {
	dx := to.X - from.X
	dy := to.Y - from.Y
	if abs(dx) >= abs(dy) {
		if dx >= 0 {
			return Point{X: 1, Y: 0}
		}
		return Point{X: -1, Y: 0}
	}
	if dy >= 0 {
		return Point{X: 0, Y: 1}
	}
	return Point{X: 0, Y: -1}
}

func clamp(value, low, high int) int {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}
