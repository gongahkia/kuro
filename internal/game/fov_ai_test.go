package game

import "testing"

func TestFOVRespectsWalls(t *testing.T) {
	level := newLevel(7, 5)
	for y := 1; y < 4; y++ {
		for x := 1; x < 6; x++ {
			level.SetTile(Point{X: x, Y: y}, TileFloor)
		}
	}
	level.SetTile(Point{X: 3, Y: 2}, TileWall)

	visible := ComputeFOV(level, Point{X: 1, Y: 2}, 6)
	if visible[Point{X: 5, Y: 2}] {
		t.Fatal("expected wall to block line of sight to tile behind it")
	}
	if !visible[Point{X: 2, Y: 2}] {
		t.Fatal("expected open tile before wall to remain visible")
	}
}

func TestAIUsesWalkablePathAroundWalls(t *testing.T) {
	level := newLevel(7, 7)
	for y := 1; y < 6; y++ {
		level.SetTile(Point{X: 1, Y: y}, TileFloor)
		level.SetTile(Point{X: 5, Y: y}, TileFloor)
	}
	for x := 1; x < 6; x++ {
		level.SetTile(Point{X: x, Y: 5}, TileFloor)
	}

	enemy := Enemy{
		Kind:        EnemyStalker,
		Pos:         Point{X: 1, Y: 1},
		State:       EnemyStateSearch,
		LastSeen:    Point{X: 5, Y: 1},
		AlertTurns:  2,
		SearchTurns: 2,
	}
	player := Player{Pos: Point{X: 5, Y: 1}}
	action := aiForKind(enemy.Kind).NextAction(LevelView{
		Level:              &level,
		Occupied:           map[Point]bool{enemy.Pos: true},
		DistanceToPlayer:   BuildDistanceMap(level, []Point{player.Pos}, nil),
		DistanceFromPlayer: BuildDarknessMap(level, map[Point]bool{}, map[Point]bool{enemy.Pos: true}),
		VisibleToPlayer:    map[Point]bool{},
	}, ActorState{
		Self:        enemy,
		Player:      player,
		AlarmActive: true,
	})

	if action.Kind != ActionMove {
		t.Fatalf("expected move action, got %v", action.Kind)
	}
	if action.Target != (Point{X: 1, Y: 2}) {
		t.Fatalf("expected path to start by moving down corridor, got %v", action.Target)
	}
}

func TestLeechRetreatPrefersDarkness(t *testing.T) {
	level := newLevel(7, 7)
	for y := 1; y < 6; y++ {
		for x := 1; x < 6; x++ {
			level.SetTile(Point{X: x, Y: y}, TileFloor)
		}
	}

	enemy := Enemy{
		Kind:         EnemyLeech,
		Pos:          Point{X: 3, Y: 3},
		State:        EnemyStateRetreat,
		RetreatTurns: 2,
	}
	player := Player{Pos: Point{X: 5, Y: 3}}
	visible := map[Point]bool{
		{X: 3, Y: 3}: true,
		{X: 4, Y: 3}: true,
		{X: 5, Y: 3}: true,
		{X: 3, Y: 2}: true,
	}
	action := aiForKind(enemy.Kind).NextAction(LevelView{
		Level:              &level,
		Occupied:           map[Point]bool{enemy.Pos: true},
		DistanceToPlayer:   BuildDistanceMap(level, []Point{player.Pos}, nil),
		DistanceFromPlayer: BuildDarknessMap(level, visible, map[Point]bool{enemy.Pos: true}),
		VisibleToPlayer:    visible,
	}, ActorState{
		Self:   enemy,
		Player: player,
	})

	if action.Kind != ActionMove {
		t.Fatalf("expected move action, got %v", action.Kind)
	}
	if action.Target == (Point{X: 4, Y: 3}) {
		t.Fatal("leech should retreat away from the player, not toward them")
	}
}
