package light

import (
	"fmt"
	"math/rand"
	"time"
	"kuro/lib/utils"
)

type Torches struct {
	MaxNumberTorches int
	Positions []map[string]int
}

func NewTorches() *Torches{
	return &Torches{
		Positions: []map[string]int{}
	}
}

func (t Torches) GenerateTorchPositions(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, PlayerPosition map[string]int, probability int){ 
	rand.Seed(time.Now().UnixNano())
	var desiredProbability int
	var tempCount int
	desiredProbability = 100 - probability
	tempCount = 0
	for y := minYCoordinateWalls; y <= maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x <= maxXCoordinateWalls; x++{
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if tempCount == t.MaxNumberTorches {
				return
			} else if rand.Intn(100) > desiredProbability && !utils.Contains(WallPositions, curr) && !(PlayerPosition["x"] == curr["x"] && PlayerPosition["y"] == curr["y"]) {
				t.Positions = append(t.Positions, curr)
				tempCount++	
			} else {}
		}
	}
}