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

func Abs(x int) int {
    if x < 0 {
        return -x
    }
    return x
}

func SanitiseScope(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, inputSlice []map[string]int) []map[string]int{
	fin := []map[string]int{}
	for _, coordinate := range inputSlice {
		if coordinate["x"] > minXCoordinateWalls && coordinate["x"] < maxXCoordinateWalls && coordinate["y"] > minYCoordinateWalls && coordinate["y"] < maxYCoordinateWalls {
			fin = append(fin, coordinate)
		} else {}
	}
	return fin
}

func IlluminatedNoTorch(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, PlayerPosition map[string]int, lengthHeightIllumination int)[]map[string]int{
	fin := []map[string]int{}
	currX := PlayerPosition["x"]
	currY := PlayerPosition["y"]
	for y := currY - lengthHeightIllumination; y <= currY + lengthHeightIllumination; y++ {
		for x := currX - lengthHeightIllumination; x <= currX + lengthHeightIllumination; x++ {
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			fin = append(fin, curr)
		}
	}
	return SanitiseScope(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, fin)
}

func IlluminatedWithTorch(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, PlayerPosition map[string]int, lengthHeightIllumination int) []map[string]int {
    currX := PlayerPosition["x"]
    currY := PlayerPosition["y"]
    fin := []map[string]int{}

    for x := -lengthHeightIllumination; x <= lengthHeightIllumination; x++ {
        for y := -lengthHeightIllumination; y <= lengthHeightIllumination; y++ {
            if Abs(x) + Abs(y) <= lengthHeightIllumination {
                fin = append(fin, map[string]int{"x": currX + x, "y": currY + y})
            }
        }
    }
    return SanitiseScope(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, fin)
}

/*

// FUA
	// work on this last
	// finish up this function to read a txt file for random shape generation to be randomly placed within other files and return a bunch of coordinates
	// function has to check the size of the object and scale it accordingly
	// consider writing a scale up and scale down function that appropriately scales a given object of specified coordinates
		// is there some secret math hack i can use here?
		// google whether it is possible to write a go function that either does the thing I want, or throws an error if execution fails

func Deserialize(filePath string, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)[]map[string]int{

}

*/