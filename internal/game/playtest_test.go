package game

import "testing"

func TestAutomatedSoakAcrossSeedsAndDifficulties(t *testing.T) {
	seeds := []int64{17, 29, 43}
	difficulties := []Difficulty{DifficultyApprentice, DifficultyStalker, DifficultyNightmare}

	for _, difficulty := range difficulties {
		for _, seed := range seeds {
			run, err := NewRun(difficulty, seed)
			if err != nil {
				t.Fatalf("new run difficulty=%s seed=%d: %v", difficulty.Label(), seed, err)
			}
			run.Player.MaxHealth = 999
			run.Player.Health = 999

			for step := 0; step < 4500 && !run.Dead && !run.Victory; step++ {
				run.Enemies = nil
				run.Boss.Telegraphs = map[Point]int{}
				run.Boss.Hazards = map[Point]int{}
				target, ok := run.currentObjectiveTarget()
				if !ok {
					t.Fatalf("difficulty=%s seed=%d lost objective on floor %d", difficulty.Label(), seed, run.Floor)
				}
				command := commandToward(run, target)
				run.Step(command)
				run.Player.Health = 999
			}

			if run.Dead {
				t.Fatalf("difficulty=%s seed=%d should not die in soak run", difficulty.Label(), seed)
			}
			if !run.Victory {
				t.Fatalf("difficulty=%s seed=%d did not finish within step budget", difficulty.Label(), seed)
			}
		}
	}
}
