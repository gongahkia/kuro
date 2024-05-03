// FUA
    // add a title screen with the instructions, "find the torches before time runs out", "don't get caught by bob"
    // further add a prompt that BOB IS CHASING YOU when he is within render view

package main

import (
    "fmt"
    "os"
    "kuro/lib/utils"
    "kuro/lib/graphics"
    "kuro/lib/entity/player"
    "kuro/lib/environment/walls"
    "kuro/lib/environment/light"
    "kuro/lib/entity/enemy"
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
    var enemyStartingCoordinates map[string]int
    var enemySpeed int
    var enemyHealth int

    minXCoordinateWalls = 0
    maxXCoordinateWalls = 16
    minYCoordinateWalls = 0
    maxYCoordinateWalls = 16
    playerStartingXCoordinate = 0 // this will be reassigned anyway
    playerStartingYCoordinate = 0 // this will be reassigned anyway
    numStartingTorches = 0
    maxNumberTorches = 3
    lengthHeightIlluminationNoTorch = 2
    lengthHeightIlluminationWithTorch = 3
    // enemyStartingCoordinates = map[string]int{
    //     "x": 12,
    //     "y": 12,
    // }
    enemySpeed = 1
    enemyHealth = 1

    b1 := walls.NewBoundaryWalls(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)
    b1.GenerateBoundaryWalls()
    // fmt.Println(b1.Positions) 

    fmt.Println("Enter player name: ")
    playerName = utils.ReadInput()
    p1 := player.NewPlayerCharacter(playerName, playerStartingXCoordinate, playerStartingYCoordinate, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, numStartingTorches)
    p1.GetRandomSpawnCoordinates(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)

    t1 := light.NewTorches(maxNumberTorches)
    t1.GenerateTorchPositions(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, p1.Position) 
    // fmt.Println(t1.Positions)

    e1 := enemy.NewEnemyCharacter(enemySpeed, enemyHealth, enemyStartingCoordinates, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls)
    e1.GetRandomSpawnCoordinates(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, p1.Position, t1.Positions)

    // --- game loop ---

    for {
        // debug info
        fmt.Println("num torches are", p1.NumTorches)
        // fmt.Println(t1)

        // render graphics
        if p1.NumTorches > 0 { // has a torch
            graphics.DrawWithTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position, lengthHeightIlluminationWithTorch)
        } else if p1.NumTorches == 0 { // has no torch
            graphics.DrawNoTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position, lengthHeightIlluminationNoTorch)
        } else {} // weird edge case (should never be hit)

        // win condition
        if len(t1.Positions) == 0 {
            graphics.DrawNoShader(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position)
            fmt.Println("Congratulations", p1.Name, ",you have collected all the torches. \nYou win!")
            fmt.Println("Closing window")
            os.Exit(0)
        }

        // lose condition
        if e1.Position["x"] == p1.Position["x"] && e1.Position["y"] == p1.Position["y"] {
            graphics.DrawNoShader(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position)
            fmt.Println("Oh no", p1.Name, ",you have been caught by Bob. \nTry again next time!")
            fmt.Println("Closing window")
            os.Exit(0)
        }

        // enemy movement
        e1.SetPosition(e1.GetNextMove(p1.Position))
        // fmt.Println("enemy moved to current coordinate:", e1.Position)

        // process player input
        var keyPress rune
        keyPress = utils.ReadKeypress()
        switch keyPress{

            case 119:
                // fmt.Println("Moving up")
                if p1.MoveUp(b1.Positions, t1.Positions) {
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 97:
                // fmt.Println("Moving left")
                if p1.MoveLeft(b1.Positions, t1.Positions) {
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 115:
                // fmt.Println("Moving down")
                if p1.MoveDown(b1.Positions, t1.Positions) {
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 100:
                // fmt.Println("Moving right")
                if p1.MoveRight(b1.Positions, t1.Positions) {
                    t1.TorchPickedUp(p1.Position)
                } else {}

            case 113:
                fmt.Println("Quit")
                fmt.Println("Closing window")
                os.Exit(0)

        }
    }
}