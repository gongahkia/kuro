// FUA
	// add player type struct and its struct methods

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
}

func NewPlayerCharacter(name string, positionXs ...int, positionYs ...int, numTorchess ...int) *PlayerCharacter {

	positionX := 0
	positionY := 0
	numTorches := 0

	if len(positionXs) > 0{
		positionX = positionXs[0]
	} else {}

	if len(positionYs) > 0{
		positionY = positionYs[0]
	} else {}

	if len(numTorchess) > 0{
		numTorches = numTorchess[0]
	} else {}

	return &PlayerCharacter{ // return a pointer to the playercharacter type to construct a new player instance
		Name: name, 
		Speed: 1,
		Health: 5,
		Position: map[string]int{
			'x': positionX,
			'y': positionY,
		},
		NumTorches: numTorches
	}
}

func (p PlayerCharacter) MoveLeft(){
	p.Position["x"] -= p.Speed
	fmt.Println("Moved one cell left, current coordinates are: ", p.Position)
}

func (p PlayerCharacter) MoveRight(){
	p.Position["x"] += p.Speed
	fmt.Println("Moved one cell right, current coordinates are: ", p.Position)
}

func (p PlayerCharacter) MoveUp(){
	p.Position["y"] -= p.Speed
	fmt.Println("Moved one cell up, current coordinates are: ", p.Position)
}

func (p PlayerCharacter) MoveDown(){
	p.Position["y"] += p.Speed
	fmt.Println("Moved one cell down, current coordinates are: ", p.Position)
}

func (p PlayerCharacter) TakeDamage(damages ...int){

	damage := 1

	if len(damages) > 0{
		damage = damages[0]
	} else {}

	p.Health -= 1
	fmt.Println(p.Name, " took damage, current health is ", p.Health)

}

func (p PlayerCharacter) GetTorch(numTorchess ...int){

	numTorches := 1

	if len(numTorchess) > 0{
		numTorches = numTorchess[0]
	} else {}

	p.NumTorches += numTorches
	fmt.Println("Player picked up ", numTorches, " torches, and now has ", p.NumTorches, " torches")

}