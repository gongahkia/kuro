package light

import (
	"fmt"
	"math/rand"
	"time"
	"os"
	"kuro/lib/utils"
)

type Torches struct {
	MaxNumberTorches int
	Positions []map[string]int
}

func NewTorches(maxNumberTorches int) *Torches{
	fmt.Println("Torches have been generated")
	return &Torches{
		MaxNumberTorches: maxNumberTorches,
		Positions: []map[string]int{},
	}
}

// FUA 
	// refine the algorithm under this function used to generate random positions of torches, might have to consider algorithm i used to randomly spawn in items in tikrit lua rougelike game
func (t *Torches) GenerateTorchPositions(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, PlayerPosition map[string]int, Probability int, TorchSpawnTolerance int){ 
	rand.Seed(time.Now().UnixNano()^int64(os.Getpid())^int64(rand.Intn(10000)))
	var tempCount int
	tempCount = 0
	for y := minYCoordinateWalls; y <= maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x <= maxXCoordinateWalls; x++{
			randSeed := rand.Intn(100)
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if tempCount == t.MaxNumberTorches {
				return
			} else if randSeed < Probability && !utils.ColumnRowProximity(t.Positions, curr, TorchSpawnTolerance) && !utils.Contains(WallPositions, curr) && !(PlayerPosition["x"] == curr["x"] && PlayerPosition["y"] == curr["y"]) {
				t.Positions = append(t.Positions, curr)
				tempCount++	
			} else {}
		}
	}
}