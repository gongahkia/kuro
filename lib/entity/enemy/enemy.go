package enemy

import (
	"fmt"
	"kuro/lib/utils"
	"math/rand"
	"time"
	"os"
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
	// fmt.Println("Enemy initialised, current coordinates are:", EnemyPosition["x"], EnemyPosition["y"])
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

// moves bob in a snaking fashion
func (e EnemyCharacter) GetNextMove(PlayerPosition map[string]int) map[string]int {
	xDisplacement := PlayerPosition["x"] - e.Position["x"]
	yDisplacement := PlayerPosition["y"] - e.Position["y"]
	newPosition := map[string]int{}
	if xDisplacement == 0 { // then move y
		if yDisplacement < 0 {
			newPosition["y"] = e.Position["y"] - e.Speed
		} else {
			newPosition["y"] = e.Position["y"] + e.Speed
		}
		newPosition["x"] = e.Position["x"]
	} else if yDisplacement == 0 { // then move x
		if xDisplacement < 0 {
			newPosition["x"] = e.Position["x"] - e.Speed
		} else {
			newPosition["x"] = e.Position["x"] + e.Speed
		}
		newPosition["y"] = e.Position["y"]
	} else {
		if utils.RandBool(){ // move x
			if xDisplacement < 0 {
				newPosition["x"] = e.Position["x"] - e.Speed
			} else {
				newPosition["x"] = e.Position["x"] + e.Speed
			}
			newPosition["y"] = e.Position["y"]
		} else { // move y
			if yDisplacement < 0 {
				newPosition["y"] = e.Position["y"] - e.Speed
			} else {
				newPosition["y"] = e.Position["y"] + e.Speed
			}
			newPosition["x"] = e.Position["x"]
		}
	}
	return newPosition
}

func (e *EnemyCharacter) SetPosition(newPosition map[string]int){
	e.Position = newPosition
}

func (e *EnemyCharacter) ChangeSpeed(newSpeed int){
	e.Speed = newSpeed
	fmt.Println("enemy speed has been changed to", e.Speed)
}

func (e *EnemyCharacter) GetRandomSpawnCoordinates(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, PlayerPosition map[string]int, TorchPositions []map[string]int){
	var currX int
	var currY int
	rand.Seed(time.Now().UnixNano()^int64(os.Getpid())^int64(rand.Intn(10000)))
	for {
		currX = utils.RandomNumber(minXCoordinateWalls, maxXCoordinateWalls)
		currY = utils.RandomNumber(minYCoordinateWalls, maxYCoordinateWalls)
		if currX != PlayerPosition["x"] && currY != PlayerPosition["y"] && !utils.Contains(TorchPositions, map[string]int{"x": currX, "y": currY}){
			break	
		} else {}
	}
	e.Position = map[string]int{
		"x": currX,
		"y": currY,
	}
}