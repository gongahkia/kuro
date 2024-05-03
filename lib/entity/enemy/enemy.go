// FUA
	// add spawn conditions for the enemy

package enemy

import (
	"fmt"
	"math"
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
	fmt.Println("Enemy initialised, current coordinates are:", EnemyPosition["x"], EnemyPosition["y"])
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

// FUA its not even working right now so need to debug
func (e EnemyCharacter) GetNextMove(PlayerPosition map[string]int) map[string]int {
	euclideanDistance := math.Sqrt(math.Pow(float64(PlayerPosition["x"]-e.Position["x"]), 2) + math.Pow(float64(PlayerPosition["y"]-e.Position["y"]), 2))
	if euclideanDistance <= float64(e.Speed) {
		return e.Position
	}
	angle := math.Atan2(float64(PlayerPosition["y"]-e.Position["y"]), float64(PlayerPosition["x"]-e.Position["x"]))
	newX := e.Position["x"] + int(math.Cos(angle)*float64(e.Speed))
	newY := e.Position["y"] + int(math.Sin(angle)*float64(e.Speed))
	return map[string]int{
		"x": newX, 
		"y": newY,
	}
}


func (e *EnemyCharacter) SetPosition(newPosition map[string]int){
	e.Position = newPosition
}

func (e *EnemyCharacter) ChangeSpeed(newSpeed int){
	e.Speed = newSpeed
}
