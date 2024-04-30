// FUA
    // add character controller under lib in a further directory and allow for interaction between keypress and the character controller
    // allow rendering of player to the screen
    // figure out how to render lighting
    // make it so you start taking damage when you've been in darkness for a while

package main

import (
    "fmt"
    "kuro/lib/utils"
    "kuro/lib/graphics"
    // "kuro/lib/entity/player"
    // "kuro/lib/entity/enemy"
    // "kuro/lib/environment/world"
)

func main() {
    utils.Test()
    graphics.Draw()
    fmt.Println(utils.ReadKeypress())
}