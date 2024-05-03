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
	fmt.Println("Player Character", name, "initialised, current coordinates are:", positionX, positionY)
	return &PlayerCharacter{ 
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
	for _, position := range WallPositions {
		if p.Position["x"] == position["x"] && p.Position["y"] == position["y"] {
			return true
		} else {}
	}
	return false
}

func (p PlayerCharacter) CheckPickup(TorchPositions []map[string]int) bool{ 
	for _, position := range TorchPositions {
		if p.Position["x"] == position["x"] && p.Position["y"] == position["y"] {
			return true
		} else {}
	}
	return false
}

func (p *PlayerCharacter) MoveLeft(WallPositions []map[string]int, TorchPositions []map[string]int) bool{
	p.Position["x"] -= p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["x"] += p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
		return false
	} else if p.CheckPickup(TorchPositions) { // torch picked up
		p.GetTorch(1)
		fmt.Println("Torch picked up, current coordinates are:", p.Position)		
		return true
	} else { // no collision
		fmt.Println("Moved one cell left, current coordinates are:", p.Position)
		return false
	}
}

func (p *PlayerCharacter) MoveRight(WallPositions []map[string]int, TorchPositions []map[string]int) bool{
	p.Position["x"] += p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["x"] -= p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
		return false
	} else if p.CheckPickup(TorchPositions) { // torch picked up
		p.GetTorch(1)
		fmt.Println("Torch picked up, current coordinates are:", p.Position)		
		return true
	} else { // no collision
		fmt.Println("Moved one cell right, current coordinates are:", p.Position)
		return false
	}
}

func (p *PlayerCharacter) MoveUp(WallPositions []map[string]int, TorchPositions []map[string]int) bool{
	p.Position["y"] -= p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["y"] += p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
		return false
	} else if p.CheckPickup(TorchPositions) { // torch picked up
		p.GetTorch(1)
		fmt.Println("Torch picked up, current coordinates are:", p.Position)		
		return true
	} else { // no collision
		fmt.Println("Moved one cell up, current coordinates are:", p.Position)
		return false
	}
}

func (p *PlayerCharacter) MoveDown(WallPositions []map[string]int, TorchPositions []map[string]int) bool{
	p.Position["y"] += p.Speed
	if p.CheckCollision(WallPositions) { // there's a collision
		p.Position["y"] -= p.Speed
		fmt.Println("Wall hit, current coordinates are:", p.Position)
		return false
	} else if p.CheckPickup(TorchPositions) { // torch picked up
		p.GetTorch(1)
		fmt.Println("Torch picked up, current coordinates are:", p.Position)		
		return true
	} else { // no collision
		fmt.Println("Moved one cell down, current coordinates are:", p.Position)
		return false
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

func (p *PlayerCharacter) GetTorch(numTorches int){
	p.NumTorches += numTorches
	fmt.Println("Player picked up", numTorches, "torches, and now has", p.NumTorches, "torches")
}
