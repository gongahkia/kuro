// FUA
	// add basic logic for the enemy struct and add struct methods on enemy as well
	// add basic astar path finding as needed, perhaps i only want one instance of an enemy
	// focus on rendering the world first, the rest can wait

package enemy

import (
	"fmt"
	"math"
	"kuro/lib/utils"
)

type EnemyCharacter struct {
	Speed int
	Health int
	Position map[string]int
	MinXCoordinateWalls int
	MaxXCoordinateWalls int
	MinYCoordinateWalls int
	MaxYCoordinateWalls int
}

func NewEnemyCharacter(EnemySpeed int, EnemyHealth int, EnemyPosition map[string]int, minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int) *EnemyCharacter {
	fmt.Println("Enemy Character", name, "initialised, current coordinates are:", EnemyPosition["x"], EnemyPosition["y"])
	return &EnemyCharacter{ 
		Speed: EnemySpeed,
		Health: EnemyHealth,
		Position: map[string]int{
			"x": EnemyPosition["x"],
			"y": EnemyPosition["y"],
		},
		MinXCoordinateWalls: minXCoordinateWalls,
		MaxXCoordinateWalls: maxXCoordinateWalls,
		MinYCoordinateWalls: minYCoordinateWalls,
		MaxYCoordinateWalls: maxYCoordinateWalls,
	}
}

func (e *EnemyCharacter) GetNextMove(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, PlayerPosition map[string]int) map[string]int{
	var euclidianDistance float64
	euclidianDistance = math.Sqrt(math.Pow(float64(PlayerPosition["x"] - EnemyPosition["x"]), 2) + math.Pow(float64(PlayerPosition["y"] - EnemyPosition["y"]), 2))
	if euclidianDistance <= 1 {
		return EnemyPosition
	}
	possibleMovesSlice := []map[string]int{
		{EnemyPositon["x"] + 1, EnemyPosition["y"]}, 
		{EnemyPositon["x"] - 1, EnemyPosition["y"]},
		{EnemyPositon["x"], EnemyPosition["y"] + 1},
		{EnemyPositon["x"], EnemyPosition["y"] - 1},
	}
	var validMoveSlice []map[string]int
	for _, move := range possibleMovesSlice {
		if move["x"] >= minXCoordinateWalls && move["x"] <= maxXCoordinateWalls && move["y"] >= minYCoordinateWalls && move["y"] <= maxYCoordinateWalls && !utils.Contains(WallPositions, move) {
			validMoveSlice = append(validMoveSlice, move)
		}
	}
	var moveDistances []struct {
		Distance float64
		Coords map[string]int
	}
	for _, move := range validMoveSlice {
		moveDistances = append(moveDistances, struct {
			Distance float64
			Coords   map[string]int
		}{
			Distance: math.Sqrt(math.Pow(float64(move["x"] - PlayerPosition["x"]), 2) + math.Pow(float64(move["y"] - PlayerPosition["y"]), 2)),
			Coords: move,
		})
	}
	for i := range moveDistances {
		for j := i + 1; j < len(moveDistances); j++ {
			if moveDistances[i].Distance > moveDistances[j].Distance {
				moveDistances[i], moveDistances[j] = moveDistances[j], moveDistances[i]
			}
		}
	}
	return moveDistances[0].Coords
}

func (e *EnemyCharacter) MoveUp(){
	e.Position["y"] -= e.Speed
}

func (e *EnemyCharacter) MoveDown(){
	e.Position["y"] += e.Speed
}

func (e *EnemyCharacter) MoveLeft(){
	e.Position["x"] -= e.Speed
}

func (e *EnemyCharacter) MoveRight(){
	e.Position["x"] += e.Speed
}

func (e *EnemyCharacter) ChangeSpeed(newSpeed int){
	e.Speed = newSpeed
}
