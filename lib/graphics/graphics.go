// FUA
	// add logic for rendering the world by receiving fixed coordinates
	// allow for rendering different layers to enable dithering lighting for the player character and how such lighting interacts with walls

package graphics

import (
	"fmt"
	"kuro/lib/utils"
	"github.com/fatih/color"
)

func Draw(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, TorchPositions []map[string]int, PlayerPosition map[string]int) { // FUA wallpositions here to be a combined array of both boundary and inner walls

	// color initialisation

	Red := color.New(color.FgRed, color.Bold)
	Green := color.New(color.FgGreen)
	Yellow := color.New(color.FgYellow)
	// Blue := color.New(color.FgBlue)
	// Magenta := color.New(color.FgMagenta)
	// Cyan := color.New(color.FgCyan)
	// White := color.New(color.FgWhite)

	fmt.Println("Drawing world")
	for y := minYCoordinateWalls; y <= maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x <= maxXCoordinateWalls; x++{
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if utils.Contains(WallPositions, curr) { // wall found at current position, so draw wall
				Red.Print("#")
			} else if curr["x"] == PlayerPosition["x"] && curr["y"] == PlayerPosition["y"] { // player found at current position, so draw player
				Green.Print("@")
			} else if utils.Contains(TorchPositions, curr) { // torches found at current position, so draw torch
				Yellow.Print("!")
			} else { // nothing found at current position, so draw empty space
				fmt.Printf(" ")
			}
		}
		fmt.Printf("\n")
	}
}

/*

func Deserialize(filePath string, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)[]map[string]int{
	// FUA
		// finish up this function to read a txt file for random shape generation to be randomly placed within other files and return a bunch of coordinates
		// function has to check the size of the object and scale it accordingly
		// consider writing a scale up and scale down function that appropriately scales a given object of specified coordinates
			// is there some secret math hack i can use here?
			// google whether it is possible to write a go function that either does the thing I want, or throws an error if execution fails
}

*/