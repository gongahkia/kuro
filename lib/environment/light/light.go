// FUA
	// add code to randomly generate position of torches

package light

import (
	"fmt"
)

type Torches struct {
	MaxNumberTorches int
	Positions []map[string]int
}

func NewTorches() *Torches{
	return &Torches{
		Positions: {}
	}
}

func (t Torches) GenerateTorchPositions(WallPositions []map[string]int){
	// FUA add code here to generate torch positions after considering all combined wall positions
}