package graphics

import (
	"fmt"
	"kuro/lib/utils"
	"github.com/fatih/color"
)

func DrawTitleScreen(){
	// color initialisation
	Red := color.New(color.FgRed, color.Bold)
	Green := color.New(color.FgGreen)
	Magenta := color.New(color.FgMagenta)
	Yellow := color.New(color.FgYellow)
	Blue := color.New(color.FgBlue)
	Cyan := color.New(color.FgCyan)

	// color rendering
	Blue.Print("K U R O\n\n")
	Cyan.Print("There are two rules\n")	
	Cyan.Print("1. Find all the torches\n")	
	Cyan.Print("2. Don't get caught by IT\n\n")	
	Green.Print("@ <-- this is you\n")
	Yellow.Print("! <-- these are torches\n")
	Red.Print("# <-- these are walls\n")
	Magenta.Print("? <-- this is IT\n\n")
	Cyan.Print("[W] [A] [S] [D] to move\n\n")	
}

func DrawNoTorch(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, TorchPositions []map[string]int, PlayerPosition map[string]int, EnemyPosition map[string]int, lengthHeightIllumination int) { 
	// variable initialisation
	var visibleShader []map[string]int

	// color initialisation

	Red := color.New(color.FgRed, color.Bold)
	Green := color.New(color.FgGreen)
	Magenta := color.New(color.FgMagenta)
	Yellow := color.New(color.FgYellow)
	White := color.New(color.FgWhite)
	// Blue := color.New(color.FgBlue)
	// Cyan := color.New(color.FgCyan)

	visibleShader = IlluminatedNoTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, PlayerPosition, WallPositions, lengthHeightIllumination)

	// fmt.Println("Drawing world")
	for y := minYCoordinateWalls; y <= maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x <= maxXCoordinateWalls; x++{
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if utils.Contains(visibleShader, curr){ // coordinate is visible so draw appropriate character
				if utils.Contains(WallPositions, curr) { // wall found at current position, so draw wall
					Red.Print("#")
				} else if curr["x"] == PlayerPosition["x"] && curr["y"] == PlayerPosition["y"] { // player found at current position, so draw player
					Green.Print("@")
				} else if curr["x"] == EnemyPosition["x"] && curr["y"] == EnemyPosition["y"] {
					Magenta.Print("?")
				} else if utils.Contains(TorchPositions, curr) { // torches found at current position, so draw torch
					Yellow.Print("!")
				} else { // nothing found at current position, so draw empty space
					fmt.Printf(" ")
				}
			} else { // coordinate is not visible so draw darkness
				White.Print("*")
			}
		}
		fmt.Printf("\n")
	}
}

func DrawWithTorch(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, TorchPositions []map[string]int, PlayerPosition map[string]int, EnemyPosition map[string]int, lengthHeightIllumination int) { 

	// variable initialisation
	var visibleShader []map[string]int

	// color initialisation

	Red := color.New(color.FgRed, color.Bold)
	Green := color.New(color.FgGreen)
	Magenta := color.New(color.FgMagenta)
	Yellow := color.New(color.FgYellow)
	White := color.New(color.FgWhite)
	// Blue := color.New(color.FgBlue)
	// Cyan := color.New(color.FgCyan)

	visibleShader = IlluminatedWithTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, PlayerPosition, WallPositions, lengthHeightIllumination)

	// fmt.Println("Drawing world")
	for y := minYCoordinateWalls; y <= maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x <= maxXCoordinateWalls; x++{
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if utils.Contains(visibleShader, curr){ // coordinate is visible so draw appropriate character
				if utils.Contains(WallPositions, curr) { // wall found at current position, so draw wall
					Red.Print("#")
				} else if curr["x"] == PlayerPosition["x"] && curr["y"] == PlayerPosition["y"] { // player found at current position, so draw player
					Green.Print("@")
				} else if curr["x"] == EnemyPosition["x"] && curr["y"] == EnemyPosition["y"] {
					Magenta.Print("?")
				} else if utils.Contains(TorchPositions, curr) { // torches found at current position, so draw torch
					Yellow.Print("!")
				} else { // nothing found at current position, so draw empty space
					fmt.Printf(" ")
				}
			} else { // coordinate is not visible so draw darkness
				White.Print("*")
			}
		}
		fmt.Printf("\n")
	}
}

func DrawNoShader(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, TorchPositions []map[string]int, PlayerPosition map[string]int, EnemyPosition map[string]int) { 

	Red := color.New(color.FgRed, color.Bold)
	Green := color.New(color.FgGreen)
	Magenta := color.New(color.FgMagenta)
	Yellow := color.New(color.FgYellow)
	// Blue := color.New(color.FgBlue)
	// Cyan := color.New(color.FgCyan)
	// White := color.New(color.FgWhite)

	// fmt.Println("Drawing world")
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
			} else if curr["x"] == EnemyPosition["x"] && curr["y"] == EnemyPosition["y"] {
				Magenta.Print("?")
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

func SanitiseScope(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, inputSlice []map[string]int, WallPositions []map[string]int) []map[string]int{
	fin := []map[string]int{}
	for _, coordinate := range inputSlice {
		if coordinate["x"] > minXCoordinateWalls && coordinate["x"] < maxXCoordinateWalls && coordinate["y"] > minYCoordinateWalls && coordinate["y"] < maxYCoordinateWalls {
			fin = append(fin, coordinate)
		} else if utils.Contains(WallPositions, coordinate){
			fin = append(fin, coordinate)
		}
	}
	return fin
}

func IlluminatedNoTorch(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, PlayerPosition map[string]int, WallPositions []map[string]int, lengthHeightIllumination int)[]map[string]int{
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
	return SanitiseScope(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, fin, WallPositions)
}

func IlluminatedWithTorch(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, PlayerPosition map[string]int, WallPositions []map[string]int, lengthHeightIllumination int) []map[string]int {
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
    return SanitiseScope(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, fin, WallPositions)
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