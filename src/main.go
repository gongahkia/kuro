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
	"github.com/fatih/color"
)

func main() {

    // ---------- main code execution ----------

    // --- debug info ---

    // utils.Test()

    // --- color initialisation ---

	Blue := color.New(color.FgBlue, color.Bold)
	Red := color.New(color.FgRed, color.Bold)
	Green := color.New(color.FgGreen)
	Cyan := color.New(color.FgCyan)

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

    fmt.Print("\033[H\033[2J")
    graphics.DrawTitleScreen()
    Cyan.Print("provide the name you will be martyred by: ")
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
        // ansi escape code clears screen
        fmt.Print("\033[H\033[2J")

        // debug info
        // fmt.Println(t1)

        // render graphics
        if p1.NumTorches > 0 { // has a torch
            graphics.DrawWithTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position, lengthHeightIlluminationWithTorch)
        } else if p1.NumTorches == 0 { // has no torch
            graphics.DrawNoTorch(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position, lengthHeightIlluminationNoTorch)
        } else {} // weird edge case (should never be hit)

        // hud info
        Cyan.Print("\ntorches collected: ", p1.NumTorches, " / ", maxNumberTorches, "\n")

        // win condition
        if len(t1.Positions) == 0 {
            fmt.Print("\033[H\033[2J")
            graphics.DrawNoShader(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position)
            Green.Print("Congratulations ", p1.Name, ",you have collected all the torches. \nYou win!\n")
            Cyan.Print("Closing window")
            os.Exit(0)
        }

        // lose condition
        if e1.Position["x"] == p1.Position["x"] && e1.Position["y"] == p1.Position["y"] {
            fmt.Print("\033[H\033[2J")
            graphics.DrawNoShader(minXCoordinateWalls, maxXCoordinateWalls, minYCoordinateWalls, maxYCoordinateWalls, b1.Positions, t1.Positions, p1.Position, e1.Position)
            Blue.Print("\n", p1.Name, "\n")
            Red.Print("\nCAUSE OF DEATH:")
            Cyan.Print("\nShock to the nervous system")
            Red.Print("\n\nDETAILS:")
            Cyan.Print("\nVictim's limbs were found contorted at unnatural angles\nVictim's skin was covered in intricate symbols carved into their flesh, suggesting a ritualistic killing\nAlso observed complete fragmentation of the pelvis and lower spinal cord\nVictim's right calf was also entirely severed from below the knee\n\n")
            Cyan.Print("Closing window\n")
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
                fmt.Print("\033[H\033[2J")
                Cyan.Print("Quit\n")
                Cyan.Print("Closing window\n")
                os.Exit(0)

        }
    }
}