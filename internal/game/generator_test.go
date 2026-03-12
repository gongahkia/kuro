package game

import (
	"fmt"
	"math/rand"
	"sort"
	"strings"
	"testing"
)

func TestGeneratorProducesConnectedReachableObjectives(t *testing.T) {
	cfg := BuildRunConfig(DifficultyStalker, 77, 1)
	level, err := NewBSPGenerator().Generate(cfg, rand.New(rand.NewSource(77)))
	if err != nil {
		t.Fatalf("generate level: %v", err)
	}

	if !level.IsWalkable(level.Spawn) {
		t.Fatalf("spawn must be walkable: %v", level.Spawn)
	}
	if !level.IsWalkable(level.Exit) {
		t.Fatalf("exit must be walkable: %v", level.Exit)
	}
	if len(level.TorchSpawns) != cfg.TorchGoal {
		t.Fatalf("expected %d torches, got %d", cfg.TorchGoal, len(level.TorchSpawns))
	}

	distances := distanceMap(level, level.Spawn)
	for _, point := range append(append([]Point{}, level.TorchSpawns...), level.Exit) {
		if _, ok := distances[point]; !ok {
			t.Fatalf("objective %v not reachable from spawn", point)
		}
	}

	occupied := map[Point]bool{level.Spawn: true}
	for _, enemy := range level.EnemySpawns {
		if !level.IsWalkable(enemy.Pos) {
			t.Fatalf("enemy spawned in blocked tile: %v", enemy.Pos)
		}
		if occupied[enemy.Pos] {
			t.Fatalf("duplicate dynamic spawn at %v", enemy.Pos)
		}
		occupied[enemy.Pos] = true
	}
}

func TestGeneratorStableForFixedSeed(t *testing.T) {
	cfg := BuildRunConfig(DifficultyApprentice, 11, 2)
	gen := NewHybridGenerator()
	first, err := gen.Generate(cfg, rand.New(rand.NewSource(11)))
	if err != nil {
		t.Fatalf("first generate: %v", err)
	}
	second, err := gen.Generate(cfg, rand.New(rand.NewSource(11)))
	if err != nil {
		t.Fatalf("second generate: %v", err)
	}

	s1 := levelSnapshot(first)
	s2 := levelSnapshot(second)
	if s1 != s2 {
		t.Fatalf("expected deterministic level generation\nfirst:\n%s\nsecond:\n%s", s1, s2)
	}
}

func TestCaveGeneratorProducesTaggedConnectedRegions(t *testing.T) {
	cfg := BuildRunConfig(DifficultyStalker, 200, 2)
	level, err := NewCaveGenerator().Generate(cfg, rand.New(rand.NewSource(200)))
	if err != nil {
		t.Fatalf("generate cave level: %v", err)
	}
	if level.Archetype != ArchetypeCaverns {
		t.Fatalf("expected caverns archetype, got %s", level.Archetype.Label())
	}
	if len(level.Rooms) < 4 {
		t.Fatalf("expected multiple cave regions, got %d", len(level.Rooms))
	}
	if !allRoomsConnected(level) {
		t.Fatal("cave regions should be connected after tunneling")
	}
	loreRooms := 0
	for _, room := range level.Rooms {
		if room.Has(RoomTagLore) {
			loreRooms++
		}
	}
	if loreRooms == 0 {
		t.Fatal("expected at least one lore room in decorated cave levels")
	}
}

func TestBossFloorContainsReachableAnchors(t *testing.T) {
	cfg := BuildRunConfig(DifficultyNightmare, 1337, 3)
	level, err := NewBSPGenerator().Generate(cfg, rand.New(rand.NewSource(1337)))
	if err != nil {
		t.Fatalf("generate boss floor: %v", err)
	}
	if level.BossRoomID < 0 {
		t.Fatal("expected a boss room")
	}

	anchors := []Point{}
	for y := 0; y < level.Height; y++ {
		for x := 0; x < level.Width; x++ {
			p := Point{X: x, Y: y}
			if level.TileAt(p).Kind == TileAnchor {
				anchors = append(anchors, p)
			}
		}
	}
	if len(anchors) != 3 {
		t.Fatalf("expected 3 anchors, got %d", len(anchors))
	}

	distances := distanceMap(level, level.Spawn)
	for _, anchor := range anchors {
		if _, ok := distances[anchor]; !ok {
			t.Fatalf("anchor %v not reachable from spawn", anchor)
		}
	}
}

func TestDifficultyScalingInvariants(t *testing.T) {
	apprentice := BuildRunConfig(DifficultyApprentice, 1, 1)
	stalker := BuildRunConfig(DifficultyStalker, 1, 1)
	nightmare := BuildRunConfig(DifficultyNightmare, 1, 1)
	floorThree := BuildRunConfig(DifficultyStalker, 1, 3)

	if !(apprentice.MapWidth < stalker.MapWidth && stalker.MapWidth < nightmare.MapWidth) {
		t.Fatal("map widths should increase with difficulty")
	}
	if !(apprentice.ThreatBudget < stalker.ThreatBudget && stalker.ThreatBudget < nightmare.ThreatBudget) {
		t.Fatal("threat budget should increase with difficulty")
	}
	if floorThree.TorchGoal <= stalker.TorchGoal {
		t.Fatal("later floors should demand more torches")
	}
}

func levelSnapshot(level Level) string {
	rows := make([]string, 0, level.Height+8)
	for y := 0; y < level.Height; y++ {
		var row strings.Builder
		for x := 0; x < level.Width; x++ {
			row.WriteRune(level.TileAt(Point{X: x, Y: y}).Glyph())
		}
		rows = append(rows, row.String())
	}
	rows = append(rows, fmt.Sprintf("spawn=%v exit=%v boss=%d", level.Spawn, level.Exit, level.BossRoomID))
	torches := append([]Point{}, level.TorchSpawns...)
	sort.Slice(torches, func(i, j int) bool {
		if torches[i].Y == torches[j].Y {
			return torches[i].X < torches[j].X
		}
		return torches[i].Y < torches[j].Y
	})
	rows = append(rows, fmt.Sprintf("torches=%v", torches))
	return strings.Join(rows, "\n")
}
