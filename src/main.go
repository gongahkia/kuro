// FUA
    // add character controller under lib in a further directory and allow for interaction between keypress and the character controller
    // allow rendering of player to the screen
    // figure out how to render lighting

package main

import (
    "fmt"
    "kuro/lib/utils"
    "kuro/lib/graphics"
)

func main() {
    utils.Test()
    graphics.Draw()
    fmt.Println(utils.ReadKeypress())
}