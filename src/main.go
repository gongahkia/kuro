// FUA
    // add character controller under lib in a further directory and allow for interaction between keypress and the character controller
    // allow rendering of player to the screen
    // figure out how to render lighting
    // make it so you start taking damage when you've been in darkness for a while

package main

import (
    "fmt"
    "os"
    "kuro/lib/utils"
    "kuro/lib/graphics"
    "kuro/lib/entity/player"
    // "kuro/lib/environment/walls"
    // "kuro/lib/environment/light"
    // "kuro/lib/entity/enemy"
)

func main() {

    // ---------- main code execution ----------

    utils.Test()
    graphics.Draw()

    var playerName string
    var playerStartingXCoordinate int
    var playerStartingYCoordinate int
    var numStartingTorches int

    playerStartingXCoordinate = 0
    playerStartingYCoordinate = 0
    numStartingTorches = 0

    minXCoordinateWalls := 0
    maxXCoordinateWalls := 31
    minYCoordinateWalls := 0
    maxYCoordinateWalls := 31

    fmt.Println("Enter player name: ")
    playerName = utils.ReadInput()
    p1 := player.NewPlayerCharacter(playerName, playerStartingXCoordinate, playerStartingYCoordinate, minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, numStartingTorches);

    for {
        var keyPress rune
        keyPress = utils.ReadKeypress()

        // process player input

        switch keyPress{

            case 119:
                fmt.Println("Moving up")
                p1.MoveUp()

            case 97:
                fmt.Println("Moving left")
                p1.MoveLeft()

            case 115:
                fmt.Println("Moving down")
                p1.MoveDown()

            case 100:
                fmt.Println("Moving right")
                p1.MoveRight()

            case 113:
                fmt.Println("Quit")
                fmt.Println("Closing window")
                os.Exit(0)

        }
    }
}