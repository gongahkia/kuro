// FUA
	// add logic for rendering the world by receiving fixed coordinates
	// allow for rendering different layers to enable dithering lighting for the player character and how such lighting interacts with walls

package graphics

import (
	"fmt"
	"kuro/lib/utils"
)

func Draw(minXCoordinateWalls int, maxXCoordinateWalls int, minYCoordinateWalls int, maxYCoordinateWalls int, WallPositions []map[string]int, TorchPositions []map[string]int, PlayerPosition map[string]int) { // FUA wallpositions here to be a combined array of both boundary and inner walls
	fmt.Println("Drawing world")
	var finalRender string
	for y := minYCoordinateWalls; y <= maxYCoordinateWalls; y++{
		for x := minXCoordinateWalls; x <= maxXCoordinateWalls; x++{
			curr := map[string]int{
				"x": x,
				"y": y,
			}
			if utils.Contains(WallPositions, curr) { // wall found at current position, so draw wall
				finalRender += "#"
			} else if curr["x"] == PlayerPosition["x"] && curr["y"] == PlayerPosition["y"] { // player found at current position, so draw player
				finalRender += "@"
			} else if utils.Contains(TorchPositions, curr) { // torches found at current position, so draw torch
				finalRender += "!"
			} else { // nothing found at current position, so draw empty space
				finalRender += " "
			}
		}
		finalRender += "\n"
	}
	fmt.Println(finalRender)
}