package game

import (
	"fmt"
	"math"
	"math/rand"
)

type HybridGenerator struct {
	halls   *BSPGenerator
	caverns *CaveGenerator
}

func NewHybridGenerator() *HybridGenerator {
	return &HybridGenerator{
		halls:   NewBSPGenerator(),
		caverns: NewCaveGenerator(),
	}
}

func (g *HybridGenerator) Generate(cfg RunConfig, rng *rand.Rand) (Level, error) {
	switch selectArchetype(cfg, rng) {
	case ArchetypeCaverns:
		return g.caverns.Generate(cfg, rng)
	default:
		return g.halls.Generate(cfg, rng)
	}
}

func selectArchetype(cfg RunConfig, rng *rand.Rand) MapArchetype {
	if cfg.Floor == 3 {
		return ArchetypeHalls
	}
	if cfg.Floor == 2 {
		return ArchetypeCaverns
	}
	if cfg.Difficulty == DifficultyNightmare && rng.Intn(3) == 0 {
		return ArchetypeCaverns
	}
	return ArchetypeHalls
}

type CaveGenerator struct {
	FillChance  int
	SmoothSteps int
	MinRegion   int
	LoopChance  float64
}

func NewCaveGenerator() *CaveGenerator {
	return &CaveGenerator{
		FillChance:  41,
		SmoothSteps: 4,
		MinRegion:   14,
		LoopChance:  0.25,
	}
}

func (g *CaveGenerator) Generate(cfg RunConfig, rng *rand.Rand) (Level, error) {
	var lastErr error
	for attempt := 0; attempt < 10; attempt++ {
		level, err := g.generateOnce(cfg, rng)
		if err == nil {
			return level, nil
		}
		lastErr = err
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("cave generation failed")
	}
	return Level{}, lastErr
}

func (g *CaveGenerator) generateOnce(cfg RunConfig, rng *rand.Rand) (Level, error) {
	level := newLevel(cfg.MapWidth, cfg.MapHeight)
	level.Archetype = ArchetypeCaverns

	type chamber struct {
		Center Point
		Radius int
	}
	chambers := make([]chamber, 0, 6)

	for y := 0; y < level.Height; y++ {
		for x := 0; x < level.Width; x++ {
			point := Point{X: x, Y: y}
			if x == 0 || y == 0 || x == level.Width-1 || y == level.Height-1 {
				level.SetTile(point, TileWall)
				continue
			}
			if rng.Intn(100) < g.FillChance {
				level.SetTile(point, TileWall)
			} else {
				level.SetTile(point, TileFloor)
			}
		}
	}

	for i := 0; i < 6; i++ {
		seed := chamber{
			Center: Point{
				X: rng.Intn(level.Width-6) + 3,
				Y: rng.Intn(level.Height-6) + 3,
			},
			Radius: rng.Intn(2) + 2,
		}
		chambers = append(chambers, seed)
		carveChamber(&level, seed.Center, seed.Radius)
	}

	for i := 0; i < g.SmoothSteps; i++ {
		g.smooth(&level)
	}

	for _, seed := range chambers {
		carveChamber(&level, seed.Center, seed.Radius)
	}
	for i := 1; i < len(chambers); i++ {
		carveTunnel(&level, chambers[i-1].Center, chambers[i].Center)
	}
	for i := 0; i < len(chambers)/3; i++ {
		if rng.Float64() <= g.LoopChance {
			a := chambers[rng.Intn(len(chambers))].Center
			b := chambers[rng.Intn(len(chambers))].Center
			if a != b {
				carveTunnel(&level, a, b)
			}
		}
	}

	level.Rooms = make([]Room, 0, len(chambers))
	level.RoomIndex = map[Point]int{}
	for i, seed := range chambers {
		cells := g.collectRoomCells(level, seed.Center, seed.Radius+2)
		if len(cells) < g.MinRegion {
			return Level{}, fmt.Errorf("cave chamber %d too small", i)
		}
		room := Room{
			ID:     i,
			Rect:   boundsForPoints(cells),
			Center: seed.Center,
			Cells:  cells,
			Tags:   map[RoomTag]bool{},
		}
		for _, cell := range room.Cells {
			level.RoomIndex[cell] = room.ID
		}
		level.Rooms = append(level.Rooms, room)
	}

	if !allRoomsConnected(level) {
		return Level{}, fmt.Errorf("caverns not connected")
	}
	if err := decorateLevel(&level, cfg, rng); err != nil {
		return Level{}, err
	}
	return level, nil
}

func (g *CaveGenerator) collectRoomCells(level Level, center Point, radius int) []Point {
	cells := []Point{}
	for y := center.Y - radius; y <= center.Y+radius; y++ {
		for x := center.X - radius; x <= center.X+radius; x++ {
			point := Point{X: x, Y: y}
			if !level.InBounds(point) || !level.IsWalkable(point) {
				continue
			}
			if abs(center.X-x)+abs(center.Y-y) <= radius+2 {
				cells = append(cells, point)
			}
		}
	}
	return uniquePoints(cells)
}

func boundsForPoints(points []Point) Rect {
	if len(points) == 0 {
		return Rect{}
	}
	minX, minY := points[0].X, points[0].Y
	maxX, maxY := points[0].X, points[0].Y
	for _, point := range points[1:] {
		if point.X < minX {
			minX = point.X
		}
		if point.Y < minY {
			minY = point.Y
		}
		if point.X > maxX {
			maxX = point.X
		}
		if point.Y > maxY {
			maxY = point.Y
		}
	}
	return Rect{X: minX, Y: minY, W: maxX - minX + 1, H: maxY - minY + 1}
}

func (g *CaveGenerator) smooth(level *Level) {
	next := make([][]Tile, level.Height)
	for y := 0; y < level.Height; y++ {
		next[y] = make([]Tile, level.Width)
		for x := 0; x < level.Width; x++ {
			point := Point{X: x, Y: y}
			neighbors := countWallNeighbors(*level, point)
			switch {
			case x == 0 || y == 0 || x == level.Width-1 || y == level.Height-1:
				next[y][x] = Tile{Kind: TileWall}
			case neighbors > 4:
				next[y][x] = Tile{Kind: TileWall}
			case neighbors < 4:
				next[y][x] = Tile{Kind: TileFloor}
			default:
				next[y][x] = level.TileAt(point)
			}
		}
	}
	level.Tiles = next
}

type caveRegion struct {
	ID     int
	Cells  []Point
	Bounds Rect
	Center Point
}

func (g *CaveGenerator) regions(level *Level) []caveRegion {
	visited := map[Point]bool{}
	regions := []caveRegion{}
	for y := 1; y < level.Height-1; y++ {
		for x := 1; x < level.Width-1; x++ {
			start := Point{X: x, Y: y}
			if visited[start] || !level.IsWalkable(start) {
				continue
			}
			queue := []Point{start}
			visited[start] = true
			cells := []Point{start}
			minX, minY := start.X, start.Y
			maxX, maxY := start.X, start.Y
			sumX, sumY := 0, 0

			for len(queue) > 0 {
				current := queue[0]
				queue = queue[1:]
				sumX += current.X
				sumY += current.Y
				if current.X < minX {
					minX = current.X
				}
				if current.Y < minY {
					minY = current.Y
				}
				if current.X > maxX {
					maxX = current.X
				}
				if current.Y > maxY {
					maxY = current.Y
				}
				for _, dir := range CardinalDirections {
					next := current.Add(dir)
					if visited[next] || !level.IsWalkable(next) {
						continue
					}
					visited[next] = true
					queue = append(queue, next)
					cells = append(cells, next)
				}
			}

			centerX := float64(sumX) / float64(len(cells))
			centerY := float64(sumY) / float64(len(cells))
			center := cells[0]
			best := math.MaxFloat64
			for _, cell := range cells {
				score := math.Abs(float64(cell.X)-centerX) + math.Abs(float64(cell.Y)-centerY)
				if score < best {
					best = score
					center = cell
				}
			}

			regions = append(regions, caveRegion{
				ID:    len(regions),
				Cells: cells,
				Bounds: Rect{
					X: minX,
					Y: minY,
					W: maxX - minX + 1,
					H: maxY - minY + 1,
				},
				Center: center,
			})
		}
	}
	return regions
}

func countWallNeighbors(level Level, point Point) int {
	count := 0
	for y := point.Y - 1; y <= point.Y+1; y++ {
		for x := point.X - 1; x <= point.X+1; x++ {
			if x == point.X && y == point.Y {
				continue
			}
			if !level.InBounds(Point{X: x, Y: y}) || level.TileAt(Point{X: x, Y: y}).Kind == TileWall {
				count++
			}
		}
	}
	return count
}

func carveTunnel(level *Level, from, to Point) {
	current := from
	for current.X != to.X {
		level.SetTile(current, TileFloor)
		if current.X < to.X {
			current.X++
		} else {
			current.X--
		}
	}
	for current.Y != to.Y {
		level.SetTile(current, TileFloor)
		if current.Y < to.Y {
			current.Y++
		} else {
			current.Y--
		}
	}
	level.SetTile(to, TileFloor)
}

func carveChamber(level *Level, center Point, radius int) {
	for y := center.Y - radius; y <= center.Y+radius; y++ {
		for x := center.X - radius; x <= center.X+radius; x++ {
			point := Point{X: x, Y: y}
			if !level.InBounds(point) {
				continue
			}
			if abs(center.X-x)+abs(center.Y-y) <= radius+1 {
				level.SetTile(point, TileFloor)
			}
		}
	}
}
