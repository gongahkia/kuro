// FUA
	// add player type struct and its struct methods
	// add logic to check for collisions within each wall tile AND a max and min bounds check as well 

package player

import (
	"fmt"
)

type PlayerCharacter struct {
	Name string
	Speed int
	Health int
	Position map[string]int
	NumTorches int
	MinXCoordinateWalls int
	MaxXCoordinateWalls int
	MinYCoordinateWalls int
	MaxYCoordinateWalls int
}

func NewPlayerCharacter(name string, positionX int, positionY int, minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, numTorches int) *PlayerCharacter {
	fmt.Println("Player Character", name, "initialised")
	return &PlayerCharacter{ // return a pointer to the playercharacter type to construct a new player instance
		Name: name, 
		Speed: 1,
		Health: 5,
		Position: map[string]int{
			"x": positionX,
			"y": positionY,
		},
		NumTorches: numTorches,
		MinXCoordinateWalls: minXCoordinateWalls,
		MaxXCoordinateWalls: maxXCoordinateWalls,
		MinYCoordinateWalls: minYCoordinateWalls,
		MaxYCoordinateWalls: maxYCoordinateWalls,
	}
}

func (p PlayerCharacter) CheckCollision(WallPositions []map[string]int) bool{
	for x,y := range WallPositions {
		if p.Position["x"] == x && p.Position["y"] == y {
			return True
		} else {}
	}
}

func (p PlayerCharacter) MoveLeft(WallPositions []map[string]int){
	p.Position["x"] -= p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["x"] += p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
	} else { // no collision
		fmt.Println("Moved one cell left, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) MoveRight(WallPositions []map[string]int){
	p.Position["x"] += p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["x"] -= p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
	} else { // no collision
		fmt.Println("Moved one cell right, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) MoveUp(WallPositions []map[string]int){
	p.Position["y"] -= p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["y"] += p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
	} else { // no collision
		fmt.Println("Moved one cell up, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) MoveDown(WallPositions []map[string]int){
	p.Position["y"] += p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["y"] -= p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
	} else { // no collision
		fmt.Println("Moved one cell down, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) TakeDamage(damage int){
	if p.Health > 0{
		p.Health -= damage
	} else {
		p.Health = 0
	}
	fmt.Println(p.Name, " took damage, current health is", p.Health)
}

func (p PlayerCharacter) GetTorch(numTorchess ...int){
	numTorches := 1
	if len(numTorchess) > 0{
		numTorches = numTorchess[0]
	} else {}
	p.NumTorches += numTorches
	fmt.Println("Player picked up", numTorches, "torches, and now has", p.NumTorches, "torches")
}
