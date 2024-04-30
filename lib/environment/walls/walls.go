// FUA 
    // add global dictionary that tracks state 
	// add method for innerwalls that randomises the inner walls under GenerateInnerWalls later

package walls

import (
	"fmt"
)

type BoundaryWalls struct {
	MinXCoordinateWalls int
	MaxXCoordinateWalls int
	MinYCoordinateWalls int
	MaxYCoordinateWalls int
	Positions []map[string]int
}

type InnerWalls struct {
	MinXCoordinateWalls int
	MaxXCoordinateWalls int
	MinYCoordinateWalls int
	MaxYCoordinateWalls int
	Positions []map[string]int
}

func NewBoundaryWalls(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int) *BoundaryWalls{
	return &BoundaryWalls{
		MinXCoordinateWalls: minXCoordinateWalls,
		MaxXCoordinateWalls: maxXCoordinateWalls,
		MinYCoordinateWalls: minYCoordinateWalls,
		MaxYCoordinateWalls: maxYCoordinateWalls,
		Positions: {}
	}
}

func (b BoundaryWalls) GenerateBoundaryWalls() {
	for y := b.MinYCoordinateWalls; y < b.MaxYCoordinateWalls; y++{
		for x := b.MinXCoordinateWalls; x < b.MaxXCoordinateWalls; x++{
			if x == b.MinXCoordinateWalls || x == b.MaxXCoordinateWalls || y == b.MinYCoordinateWalls || y == b.MaxYCoordinateWalls {
				b.Positions = append(b.Positions, 
					{
						"x": x,
						"y": y
					}
				)
			}
		}
	}
	fmt.Println("Boundary walls have been generated")
}

func NewInnerWalls(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int) *InnerWalls {
	return &InnerWalls{
		MinXCoordinateWalls: minXCoordinateWalls,
		MaxXCoordinateWalls: maxXCoordinateWalls,
		MinYCoordinateWalls: minYCoordinateWalls,
		MaxYCoordinateWalls: maxYCoordinateWalls,
		Positions: {}
	}
}

func (n InnerWalls) GenerateInnerWalls() {
	// FUA add logic here to populate and randomise inner wall configuration
	fmt.Println("Inner walls have been randomly generated")
}