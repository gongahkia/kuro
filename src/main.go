// FUA
    // allow rendering of player to the screen
    // figure out how to render lighting with and without a torch
    // work out rendering of inner walls
    // make it so you start taking damage when you've been in darkness for a while
    // allow for size of arena to be dynamically changed and a fixed formula to be used to calculate the resulting number of torches and subsequent dithering 

package main

import (
    "fmt"
    "os"
    "kuro/lib/utils"
    "kuro/lib/graphics"
    "kuro/lib/entity/player"
    "kuro/lib/environment/walls"
    "kuro/lib/environment/light"
    // "kuro/lib/entity/enemy"
)

func main() {

    // ---------- main code execution ----------

    // --- debug info ---

    utils.Test()

    // --- variable initialisation --- 

    var minXCoordinateWalls int
    var maxXCoordinateWalls int
    var minYCoordinateWalls int
    var maxYCoordinateWalls int
    var playerName string
    var playerStartingXCoordinate int
    var playerStartingYCoordinate int
    var maxNumberTorches int
    var numStartingTorches int
    var TorchSpawnProbability int
    var TorchSpawnTolerance int

    minXCoordinateWalls = 0
    maxXCoordinateWalls = 16
    minYCoordinateWalls = 0
    maxYCoordinateWalls = 16
    playerStartingXCoordinate = 1
    playerStartingYCoordinate = 1
    numStartingTorches = 0
    maxNumberTorches = 3
    TorchSpawnProbability = 20
    TorchSpawnTolerance = 5

    b1 := walls.NewBoundaryWalls(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)
    b1.GenerateBoundaryWalls()
    fmt.Println(b1.Positions) 

    fmt.Println("Enter player name: ")
    playerName = utils.ReadInput()
    p1 := player.NewPlayerCharacter(playerName, playerStartingXCoordinate, playerStartingYCoordinate, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, numStartingTorches)

    t1 := light.NewTorches(maxNumberTorches)
    t1.GenerateTorchPositions(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, p1.Position, TorchSpawnProbability, TorchSpawnTolerance) // FUA this should eventually take a combined slice of boundary and interior walls
    fmt.Println(t1.Positions)

    // --- game loop ---

    for {
        // render graphics
        graphics.Draw(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position)

        // process player input
        var keyPress rune
        keyPress = utils.ReadKeypress()
        switch keyPress{

            case 119:
                fmt.Println("Moving up")
                p1.MoveUp(b1.Positions) // FUA this should eventually take a combined slice of boundary and interior walls

            case 97:
                fmt.Println("Moving left")
                p1.MoveLeft(b1.Positions) // FUA this should eventually take a combined slice of boundary and interior walls

            case 115:
                fmt.Println("Moving down")
                p1.MoveDown(b1.Positions) // FUA this should eventually take a combined slice of boundary and interior walls

            case 100:
                fmt.Println("Moving right")
                p1.MoveRight(b1.Positions) // FUA this should eventually take a combined slice of boundary and interior walls

            case 113:
                fmt.Println("Quit")
                fmt.Println("Closing window")
                os.Exit(0)

        }
    }
}