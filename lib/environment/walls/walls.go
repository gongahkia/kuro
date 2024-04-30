// FUA 
    // add global dictionary that tracks state 
	// add method for innerwalls that randomises the inner walls

package walls

import (
	"fmt"
)

type BoundaryWalls struct {
	Positions []map[string]int
}

type InnerWalls struct {
	Positions []map[string]int
}

func NewBoundaryWalls() *BoundaryWalls{
	return &BoundaryWalls{
		Positions: {}
	}
}

func (b BoundaryWalls) GenerateBoundaryWalls() {
	minXCoordinateWalls := 0
	maxXCoordinateWalls := 0
	minYCoordinateWalls := 31
	maxYCoordinateWalls := 31
	for y := minYCoordinateWalls; y < maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x < maxXCoordinateWalls; x++{

		}
	}
}

func NewInnerWalls() *InnerWalls {
	return &InnerWalls{
		Positions: {}
	}
}

func (n InnerWalls) GenerateInnerWalls() {
	// FUA add logic here to populate and randomise inner wall configuration
}