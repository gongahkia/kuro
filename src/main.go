// FUA
    // make it so that enemies start spawning in the darkness and you can't see them but a red exclamation mark spawns when they spawn in 
    // implement enemey path finding they can see you
    // should i add a weight factor to this game?
        // then make weight reduce speed where speed is relative so each time you pick up or drop an item the item is a physical object that spawns in
        // also if you move slower then enemy speed just increases so they clear more tiles in a given turn (eg. increase speed 1 to 2 so every time u move one cell they move two)
        // figure out attacks and health system
    // do i want to add multiple rooms?
        // where each time you clear a room you have to choose a new buff for the enemy instead of a buff for yourself
        // highscore system where it saves to a json
        // unique deathscreen
    // allow for size of arena to be dynamically changed and a fixed formula to be used to calculate the resulting number of torches and subsequent dithering 
    // work out rendering of inner walls
        // perhaps screw the randomness for inner wall generation and just add a folder of txt files and a serialize function that reads a txt file and randomly places structures around the map if there is space
        // ensure that the inner wall randomness comes BEFORE the torches spawn in
    // to add unit tests later and update makefile accordingly

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
    var lengthHeightIlluminationNoTorch int
    var lengthHeightIlluminationWithTorch int

    minXCoordinateWalls = 0
    maxXCoordinateWalls = 16
    minYCoordinateWalls = 0
    maxYCoordinateWalls = 16
    playerStartingXCoordinate = 1
    playerStartingYCoordinate = 1
    numStartingTorches = 0
    maxNumberTorches = 3
    lengthHeightIlluminationNoTorch = 2
    lengthHeightIlluminationWithTorch = 3

    b1 := walls.NewBoundaryWalls(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)
    b1.GenerateBoundaryWalls()
    fmt.Println(b1.Positions) 

    fmt.Println("Enter player name: ")
    playerName = utils.ReadInput()
    p1 := player.NewPlayerCharacter(playerName, playerStartingXCoordinate, playerStartingYCoordinate, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, numStartingTorches)

    t1 := light.NewTorches(maxNumberTorches)
    t1.GenerateTorchPositions(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, p1.Position) // FUA this should eventually take a combined slice of boundary and interior walls
    fmt.Println(t1.Positions)

    // --- game loop ---

    for {
        // debug info
        fmt.Println("num torches are", p1.NumTorches)
        fmt.Println(t1)

        // render graphics
        if p1.NumTorches > 0 { // has a torch
            graphics.DrawWithTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, lengthHeightIlluminationWithTorch)
        } else if p1.NumTorches == 0 { // has no torch
            graphics.DrawNoTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, lengthHeightIlluminationNoTorch)
        } else {} // weird edge case (should never be hit)

        // win condition
        if len(t1.Positions) == 0 {
            graphics.DrawNoShader(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position)
            fmt.Println("Congratulations", p1.Name, ",you have collected all the torches. \nYou win!")
            fmt.Println("Closing window")
            os.Exit(0)
        }

        // process player input
        var keyPress rune
        keyPress = utils.ReadKeypress()
        switch keyPress{

            case 119:
                fmt.Println("Moving up")
                if p1.MoveUp(b1.Positions, t1.Positions) {// FUA this should eventually take a combined slice of boundary and interior walls
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 97:
                fmt.Println("Moving left")
                if p1.MoveLeft(b1.Positions, t1.Positions) {// FUA this should eventually take a combined slice of boundary and interior walls
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 115:
                fmt.Println("Moving down")
                if p1.MoveDown(b1.Positions, t1.Positions) {// FUA this should eventually take a combined slice of boundary and interior walls
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 100:
                fmt.Println("Moving right")
                if p1.MoveRight(b1.Positions, t1.Positions) {// FUA this should eventually take a combined slice of boundary and interior walls
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 113:
                fmt.Println("Quit")
                fmt.Println("Closing window")
                os.Exit(0)

        }
    }
}