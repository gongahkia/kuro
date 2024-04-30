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

func (p PlayerCharacter) MoveLeft(){
	if p.Position["x"] - p.Speed < p.MinXCoordinateWalls + 1 {
		fmt.Println("Left wall hit, current coordinates are:", p.Position)
	} else {
		p.Position["x"] -= p.Speed
		fmt.Println("Moved one cell left, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) MoveRight(){
	if p.Position["x"] + p.Speed > p.MaxXCoordinateWalls - 1 {
		fmt.Println("Right wall hit, current coordinates are:", p.Position)
	} else {
		p.Position["x"] += p.Speed
		fmt.Println("Moved one cell right, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) MoveUp(){
	if p.Position["y"] - p.Speed < p.MinYCoordinateWalls + 1 {
		fmt.Println("Upper wall hit, current coordinates are:", p.Position)
	} else {
		p.Position["y"] -= p.Speed
		fmt.Println("Moved one cell up, current coordinates are:", p.Position)
	}
}

func (p PlayerCharacter) MoveDown(){
	if p.Position["y"] + p.Speed > p.MaxYCoordinateWalls - 1 {
		fmt.Println("Lower wall hit, current coordinates are:", p.Position)
	} else {
		p.Position["y"] += p.Speed
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