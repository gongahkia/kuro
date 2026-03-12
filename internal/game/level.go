package game

import (
	"errors"
	"fmt"
	"math/rand"
	"sort"
)

type BSPGenerator struct {
	MinLeafSize int
	MinRoomSize int
	LoopChance  float64
}

func NewBSPGenerator() *BSPGenerator {
	return &BSPGenerator{
		MinLeafSize: 8,
		MinRoomSize: 4,
		LoopChance:  0.35,
	}
}

func (l *Level) InBounds(p Point) bool {
	return p.X >= 0 && p.X < l.Width && p.Y >= 0 && p.Y < l.Height
}

func (l *Level) TileAt(p Point) Tile {
	if !l.InBounds(p) {
		return Tile{Kind: TileWall}
	}
	return l.Tiles[p.Y][p.X]
}

func (l *Level) SetTile(p Point, kind TileKind) {
	if l.InBounds(p) {
		l.Tiles[p.Y][p.X] = Tile{Kind: kind}
	}
}

func (l *Level) IsWalkable(p Point) bool {
	return l.InBounds(p) && !l.TileAt(p).BlocksMove()
}

func (l *Level) BlocksSight(p Point) bool {
	return !l.InBounds(p) || l.TileAt(p).BlocksSight()
}

func (l *Level) RoomAt(p Point) (Room, int, bool) {
	index, ok := l.RoomIndex[p]
	if !ok || index < 0 || index >= len(l.Rooms) {
		return Room{}, -1, false
	}
	return l.Rooms[index], index, true
}

func newLevel(width, height int) Level {
	tiles := make([][]Tile, height)
	for y := 0; y < height; y++ {
		tiles[y] = make([]Tile, width)
		for x := 0; x < width; x++ {
			tiles[y][x] = Tile{Kind: TileWall}
		}
	}
	return Level{
		Width:      width,
		Height:     height,
		Archetype:  ArchetypeHalls,
		Tiles:      tiles,
		BossRoomID: -1,
		RoomIndex:  map[Point]int{},
	}
}

type bspNode struct {
	Rect  Rect
	Left  *bspNode
	Right *bspNode
	Room  *Room
}

func (n *bspNode) IsLeaf() bool {
	return n.Left == nil && n.Right == nil
}

func (g *BSPGenerator) Generate(cfg RunConfig, rng *rand.Rand) (Level, error) {
	var lastErr error
	for attempt := 0; attempt < 10; attempt++ {
		level, err := g.generateOnce(cfg, rng)
		if err == nil {
			return level, nil
		}
		lastErr = err
	}
	if lastErr == nil {
		lastErr = errors.New("generator failed without error")
	}
	return Level{}, lastErr
}

func (g *BSPGenerator) generateOnce(cfg RunConfig, rng *rand.Rand) (Level, error) {
	level := newLevel(cfg.MapWidth, cfg.MapHeight)
	root := g.partition(Rect{X: 1, Y: 1, W: cfg.MapWidth - 2, H: cfg.MapHeight - 2}, rng, 0)
	rooms := make([]Room, 0, 16)
	_, _ = g.carve(root, &level, rng, &rooms)
	if len(rooms) < max(4, cfg.TorchGoal+1) {
		return Level{}, fmt.Errorf("insufficient rooms: %d", len(rooms))
	}
	level.Rooms = rooms

	for i := 0; i < len(rooms)/3; i++ {
		if rng.Float64() <= g.LoopChance {
			a := rooms[rng.Intn(len(rooms))].Center
			b := rooms[rng.Intn(len(rooms))].Center
			if a != b {
				g.carveCorridor(&level, a, b, rng)
			}
		}
	}

	if !allRoomsConnected(level) {
		return Level{}, errors.New("level connectivity validation failed")
	}

	if err := decorateLevel(&level, cfg, rng); err != nil {
		return Level{}, err
	}
	return level, nil
}

func (g *BSPGenerator) partition(rect Rect, rng *rand.Rand, depth int) *bspNode {
	node := &bspNode{Rect: rect}
	tooSmallToSplit := rect.W < g.MinLeafSize*2 && rect.H < g.MinLeafSize*2
	if depth >= 6 || tooSmallToSplit {
		return node
	}

	splitHorizontal := rect.H > rect.W
	if rect.W > rect.H && float64(rect.W)/float64(rect.H) > 1.25 {
		splitHorizontal = false
	} else if rect.H > rect.W && float64(rect.H)/float64(rect.W) > 1.25 {
		splitHorizontal = true
	} else {
		splitHorizontal = rng.Intn(2) == 0
	}

	if splitHorizontal {
		maxSplit := rect.H - g.MinLeafSize
		if maxSplit <= g.MinLeafSize {
			return node
		}
		split := rng.Intn(maxSplit-g.MinLeafSize+1) + g.MinLeafSize
		node.Left = g.partition(Rect{X: rect.X, Y: rect.Y, W: rect.W, H: split}, rng, depth+1)
		node.Right = g.partition(Rect{X: rect.X, Y: rect.Y + split, W: rect.W, H: rect.H - split}, rng, depth+1)
		return node
	}

	maxSplit := rect.W - g.MinLeafSize
	if maxSplit <= g.MinLeafSize {
		return node
	}
	split := rng.Intn(maxSplit-g.MinLeafSize+1) + g.MinLeafSize
	node.Left = g.partition(Rect{X: rect.X, Y: rect.Y, W: split, H: rect.H}, rng, depth+1)
	node.Right = g.partition(Rect{X: rect.X + split, Y: rect.Y, W: rect.W - split, H: rect.H}, rng, depth+1)
	return node
}

func (g *BSPGenerator) carve(node *bspNode, level *Level, rng *rand.Rand, rooms *[]Room) (Point, bool) {
	if node == nil {
		return Point{}, false
	}
	if node.IsLeaf() {
		marginX := 1
		marginY := 1
		roomW := max(g.MinRoomSize, min(node.Rect.W-2, rng.Intn(max(1, node.Rect.W-3))+3))
		roomH := max(g.MinRoomSize, min(node.Rect.H-2, rng.Intn(max(1, node.Rect.H-3))+3))
		roomXRange := max(1, node.Rect.W-roomW-marginX)
		roomYRange := max(1, node.Rect.H-roomH-marginY)
		room := Room{
			ID: len(*rooms),
			Rect: Rect{
				X: node.Rect.X + rng.Intn(roomXRange),
				Y: node.Rect.Y + rng.Intn(roomYRange),
				W: roomW,
				H: roomH,
			},
			Tags: map[RoomTag]bool{},
		}
		room.Center = room.Rect.Center()
		node.Room = &room
		for y := room.Rect.Y; y <= room.Rect.Y2(); y++ {
			for x := room.Rect.X; x <= room.Rect.X2(); x++ {
				point := Point{X: x, Y: y}
				level.SetTile(point, TileFloor)
				level.RoomIndex[point] = room.ID
				room.Cells = append(room.Cells, point)
			}
		}
		*rooms = append(*rooms, room)
		return room.Center, true
	}

	leftCenter, leftOK := g.carve(node.Left, level, rng, rooms)
	rightCenter, rightOK := g.carve(node.Right, level, rng, rooms)
	if leftOK && rightOK {
		g.carveCorridor(level, leftCenter, rightCenter, rng)
	}
	if leftOK && (!rightOK || rng.Intn(2) == 0) {
		return leftCenter, true
	}
	if rightOK {
		return rightCenter, true
	}
	return Point{}, false
}

func (g *BSPGenerator) carveCorridor(level *Level, from, to Point, rng *rand.Rand) {
	if rng.Intn(2) == 0 {
		g.carveHorizontal(level, from.X, to.X, from.Y)
		g.carveVertical(level, from.Y, to.Y, to.X)
		return
	}
	g.carveVertical(level, from.Y, to.Y, from.X)
	g.carveHorizontal(level, from.X, to.X, to.Y)
}

func (g *BSPGenerator) carveHorizontal(level *Level, x1, x2, y int) {
	if x2 < x1 {
		x1, x2 = x2, x1
	}
	for x := x1; x <= x2; x++ {
		level.SetTile(Point{X: x, Y: y}, TileFloor)
	}
}

func (g *BSPGenerator) carveVertical(level *Level, y1, y2, x int) {
	if y2 < y1 {
		y1, y2 = y2, y1
	}
	for y := y1; y <= y2; y++ {
		level.SetTile(Point{X: x, Y: y}, TileFloor)
	}
}

func decorateLevel(level *Level, cfg RunConfig, rng *rand.Rand) error {
	startIndex := rng.Intn(len(level.Rooms))
	startRoom := &level.Rooms[startIndex]
	startRoom.Tags[RoomTagStart] = true
	level.Spawn = randomPointInRoom(*level, *startRoom, rng, nil)

	distances := distanceMap(*level, level.Spawn)
	farthest := selectRoomByDistance(*level, distances, []int{startIndex}, true)
	if farthest < 0 {
		return errors.New("failed to find farthest room")
	}

	excluded := map[int]bool{startIndex: true, farthest: true}
	if cfg.Floor == 3 {
		level.BossRoomID = farthest
		level.Rooms[farthest].Tags[RoomTagBoss] = true
		level.Exit = Point{X: -1, Y: -1}
		level.EnemySpawns = append(level.EnemySpawns, Enemy{
			ID:     len(level.EnemySpawns) + 1,
			Kind:   EnemyBoss,
			Pos:    level.Rooms[farthest].Center,
			Home:   level.Rooms[farthest].Center,
			Patrol: level.Rooms[farthest].Center,
			State:  EnemyStateChase,
			Facing: Point{
				X: 0,
				Y: 1,
			},
		})
		for _, anchor := range anchorPoints(level.Rooms[farthest]) {
			level.SetTile(anchor, TileAnchor)
		}
	} else {
		level.Rooms[farthest].Tags[RoomTagExit] = true
		level.Exit = randomPointInRoom(*level, level.Rooms[farthest], rng, nil)
		level.SetTile(level.Exit, TileExit)
	}

	safeRoomIndex := selectRoomByDistance(*level, distances, keysOf(excluded), false)
	if safeRoomIndex >= 0 {
		level.Rooms[safeRoomIndex].Tags[RoomTagSafe] = true
		safePoint := randomPointInRoom(*level, level.Rooms[safeRoomIndex], rng, map[Point]bool{level.Spawn: true, level.Exit: true})
		level.SetTile(safePoint, TileShrine)
		excluded[safeRoomIndex] = true
	}

	available := make([]int, 0, len(level.Rooms))
	for i := range level.Rooms {
		if !excluded[i] {
			available = append(available, i)
		}
	}
	if len(available) == 0 {
		for i := range level.Rooms {
			if i != startIndex {
				available = append(available, i)
			}
		}
	}
	rng.Shuffle(len(available), func(i, j int) {
		available[i], available[j] = available[j], available[i]
	})

	reserved := map[Point]bool{level.Spawn: true}
	if level.InBounds(level.Exit) {
		reserved[level.Exit] = true
	}
	for i := 0; i < cfg.TorchGoal; i++ {
		room := &level.Rooms[available[i%len(available)]]
		room.Tags[RoomTagTorch] = true
		pos := randomPointInRoom(*level, *room, rng, reserved)
		level.TorchSpawns = append(level.TorchSpawns, pos)
		level.SetTile(pos, TileTorch)
		reserved[pos] = true
	}

	loreRoomCount := min(max(1, cfg.Floor), max(1, len(available)/3))
	for i := 0; i < loreRoomCount && i < len(available); i++ {
		level.Rooms[available[len(available)-1-i]].Tags[RoomTagLore] = true
	}

	encounterCandidates := append([]int{}, available...)
	if len(encounterCandidates) == 0 {
		return errors.New("not enough rooms for encounters")
	}
	rng.Shuffle(len(encounterCandidates), func(i, j int) {
		encounterCandidates[i], encounterCandidates[j] = encounterCandidates[j], encounterCandidates[i]
	})

	encounterRooms := min(len(encounterCandidates), max(1, cfg.ThreatBudget/2))
	for i := 0; i < encounterRooms; i++ {
		room := &level.Rooms[encounterCandidates[i]]
		room.Tags[RoomTagEncounter] = true
		level.EncounterSpawns = append(level.EncounterSpawns, room.Center)
	}

	enemyBudget := cfg.ThreatBudget
	for enemyBudget > 0 {
		roomIndex := encounterCandidates[rng.Intn(len(encounterCandidates))]
		if cfg.Floor == 3 && roomIndex == level.BossRoomID {
			continue
		}
		room := level.Rooms[roomIndex]
		pos := randomPointInRoom(*level, room, rng, reserved)
		kind, cost := randomEnemyKind(cfg, rng)
		if enemyBudget-cost < 0 {
			break
		}
		level.EnemySpawns = append(level.EnemySpawns, Enemy{
			ID:     len(level.EnemySpawns) + 1,
			Kind:   kind,
			Pos:    pos,
			Home:   room.Center,
			Patrol: randomPointInRoom(*level, room, rng, map[Point]bool{pos: true}),
			State:  EnemyStateIdle,
			Facing: CardinalDirections[rng.Intn(len(CardinalDirections))],
		})
		reserved[pos] = true
		enemyBudget -= cost
	}

	return nil
}

func randomPointInRoom(level Level, room Room, rng *rand.Rand, reserved map[Point]bool) Point {
	points := append([]Point{}, room.Cells...)
	if len(points) == 0 {
		points = make([]Point, 0, room.Rect.W*room.Rect.H)
		for y := room.Rect.Y; y <= room.Rect.Y2(); y++ {
			for x := room.Rect.X; x <= room.Rect.X2(); x++ {
				p := Point{X: x, Y: y}
				if level.IsWalkable(p) {
					points = append(points, p)
				}
			}
		}
	}
	filtered := make([]Point, 0, len(points))
	for _, point := range points {
		if !level.IsWalkable(point) {
			continue
		}
		if reserved != nil && reserved[point] {
			continue
		}
		filtered = append(filtered, point)
	}
	points = filtered
	if len(points) == 0 {
		return room.Center
	}
	return points[rng.Intn(len(points))]
}

func anchorPoints(room Room) []Point {
	center := room.Center
	return []Point{
		{X: max(room.Rect.X+1, center.X-2), Y: max(room.Rect.Y+1, center.Y-1)},
		{X: min(room.Rect.X2()-1, center.X+2), Y: max(room.Rect.Y+1, center.Y-1)},
		{X: center.X, Y: min(room.Rect.Y2()-1, center.Y+2)},
	}
}

func selectRoomByDistance(level Level, distances map[Point]int, excluded []int, farthest bool) int {
	excludeMap := map[int]bool{}
	for _, index := range excluded {
		excludeMap[index] = true
	}
	type candidate struct {
		Index int
		Dist  int
	}
	candidates := make([]candidate, 0, len(level.Rooms))
	for i, room := range level.Rooms {
		if excludeMap[i] {
			continue
		}
		dist, ok := distances[room.Center]
		if !ok {
			continue
		}
		candidates = append(candidates, candidate{Index: i, Dist: dist})
	}
	if len(candidates) == 0 {
		return -1
	}
	sort.Slice(candidates, func(i, j int) bool {
		if farthest {
			return candidates[i].Dist > candidates[j].Dist
		}
		return candidates[i].Dist < candidates[j].Dist
	})
	return candidates[0].Index
}

func allRoomsConnected(level Level) bool {
	if len(level.Rooms) == 0 {
		return false
	}
	distances := distanceMap(level, level.Rooms[0].Center)
	for _, room := range level.Rooms {
		if _, ok := distances[room.Center]; !ok {
			return false
		}
	}
	return true
}

func distanceMap(level Level, start Point) map[Point]int {
	queue := []Point{start}
	distances := map[Point]int{start: 0}
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		for _, dir := range CardinalDirections {
			next := current.Add(dir)
			if !level.IsWalkable(next) {
				continue
			}
			if _, seen := distances[next]; seen {
				continue
			}
			distances[next] = distances[current] + 1
			queue = append(queue, next)
		}
	}
	return distances
}

func keysOf(input map[int]bool) []int {
	keys := make([]int, 0, len(input))
	for key := range input {
		keys = append(keys, key)
	}
	return keys
}

func randomEnemyKind(cfg RunConfig, rng *rand.Rand) (EnemyKind, int) {
	options := []struct {
		Kind EnemyKind
		Cost int
	}{
		{Kind: EnemyStalker, Cost: 1},
		{Kind: EnemyRusher, Cost: 2},
		{Kind: EnemySentry, Cost: 2},
		{Kind: EnemyLeech, Cost: 2},
	}
	if cfg.Floor == 1 {
		options = options[:2]
	}
	choice := options[rng.Intn(len(options))]
	return choice.Kind, choice.Cost
}
