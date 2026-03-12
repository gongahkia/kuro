package game

import "testing"

func TestEncounterTriggersOnceOnRoomEntry(t *testing.T) {
	run, err := NewRun(DifficultyApprentice, 55)
	if err != nil {
		t.Fatalf("new run: %v", err)
	}

	var room Room
	var roomIndex int
	found := false
	for i, candidate := range run.Level.Rooms {
		if candidate.Has(RoomTagEncounter) {
			room = candidate
			roomIndex = i
			found = true
			break
		}
	}
	if !found {
		t.Fatal("expected an encounter room")
	}

	run.Player.Pos = room.Center
	run.CurrentRoom = -1
	run.Director.Cooldown = 0
	run.Director.ThreatRemaining = 1
	initialMessages := len(run.Messages)
	run.triggerRoomEncounter()

	if !run.Director.TriggeredRooms[roomIndex] {
		t.Fatal("room should be marked as triggered")
	}
	if run.Stats.EncountersTriggered != 1 {
		t.Fatalf("expected encounter count 1, got %d", run.Stats.EncountersTriggered)
	}
	if len(run.Messages) == initialMessages {
		t.Fatal("expected encounter to produce feedback")
	}

	run.triggerRoomEncounter()
	if run.Stats.EncountersTriggered != 1 {
		t.Fatal("encounter should not trigger twice for the same room")
	}
}

func TestSeededRunSmokeAcrossThreeFloors(t *testing.T) {
	run, err := NewRun(DifficultyApprentice, 101)
	if err != nil {
		t.Fatalf("new run: %v", err)
	}

	run.Player.MaxHealth = 999
	run.Player.Health = 999
	steps := 0
	for !run.Victory && !run.Dead && steps < 3000 {
		run.Enemies = nil
		run.Boss.Telegraphs = map[Point]int{}
		run.Boss.Hazards = map[Point]int{}
		target, ok := run.currentObjectiveTarget()
		if !ok {
			t.Fatal("expected an available objective")
		}
		command := commandToward(run, target)
		run.Step(command)
		run.Player.Health = 999
		steps++
	}

	if run.Dead {
		t.Fatal("smoke run should not die")
	}
	if !run.Victory {
		t.Fatalf("expected victory within step budget, stopped at floor %d after %d steps", run.Floor, steps)
	}
}

func commandToward(run *Run, target Point) Command {
	if run.Player.Pos == target {
		return CommandWait
	}
	path := FindPath(run.Level, run.Player.Pos, target, nil)
	if len(path) < 2 {
		return CommandWait
	}
	next := path[1]
	switch {
	case next.Y < run.Player.Pos.Y:
		return CommandMoveUp
	case next.X > run.Player.Pos.X:
		return CommandMoveRight
	case next.Y > run.Player.Pos.Y:
		return CommandMoveDown
	case next.X < run.Player.Pos.X:
		return CommandMoveLeft
	default:
		return CommandWait
	}
}
