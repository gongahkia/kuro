package light

import (
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
	// fmt.Println("Torches have been generated")
	return &Torches{
		MaxNumberTorches: maxNumberTorches,
		Positions: []map[string]int{},
	}
}

func (t *Torches) GenerateTorchPositions(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, PlayerPosition map[string]int){ 
	var tempCount int
	tempCount = 0
	rand.Seed(time.Now().UnixNano()^int64(os.Getpid())^int64(rand.Intn(10000)))
	for {
		if tempCount == t.MaxNumberTorches {
			return
		} else {
			x := utils.RandomNumber(minXCoordinateWalls, maxXCoordinateWalls)
			y := utils.RandomNumber(minYCoordinateWalls, maxYCoordinateWalls)
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if !utils.Contains(t.Positions, curr) && !utils.Contains(WallPositions, curr) && !(PlayerPosition["x"] == curr["x"] && PlayerPosition["y"] == curr["y"]){
				t.Positions = append(t.Positions, curr)
				tempCount++	
			} else {}
		}
	}
}

func (t *Torches) TorchPickedUp(TorchPosition map[string]int){
	newPositionSlice := []map[string]int{}
	for _, val := range t.Positions {
		if val["x"] == TorchPosition["x"] && val["y"] == TorchPosition["y"] {
		} else {
			newPositionSlice = append(newPositionSlice, val)
		}
	}
	t.Positions = newPositionSlice
}