// FUA 
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
		Positions: []map[string]int{},
	}
}

func (b *BoundaryWalls) GenerateBoundaryWalls() { // note this has to be a pointer receiver method 
	for y := b.MinYCoordinateWalls; y <= b.MaxYCoordinateWalls; y++{
		for x := b.MinXCoordinateWalls; x <= b.MaxXCoordinateWalls; x++{
			if x == b.MinXCoordinateWalls || x == b.MaxXCoordinateWalls || y == b.MinYCoordinateWalls || y == b.MaxYCoordinateWalls {
				pos := map[string]int{
					"x": x, 
					"y":y,
				}
				b.Positions = append(b.Positions, pos)
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
		Positions: []map[string]int{},
	}
}

func (n InnerWalls) GenerateInnerWalls(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int) {
	// FUA add logic here to populate and randomise inner wall configuration --> WORK THIS OUT LAST
	fmt.Println("Inner walls have been randomly generated")
}