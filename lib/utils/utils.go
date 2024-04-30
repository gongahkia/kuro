package utils

import (
    "bufio"
    "fmt"
    "os"
)

func Test() {
    fmt.Println("Kuro")
}

func ReadKeypress() rune {
    s := bufio.NewReader(os.Stdin)
    char, _, err := s.ReadRune()
    if err != nil {
        fmt.Println("Error hit while reading keypress:", err)
        return 0
    }
    return char
}

func ReadInput() string {
    var in string
    _, err := fmt.Scanln(&in)
    if err != nil {
        fmt.Println("Error hit while reading input:", err)
        return "0"
    } 
    return in
}

func CombineWallSlices(WallPositions1 []map[string]int WallPositions2 []map[string]int) []map[string]int{
    return append(WallPositions1, WallPositions2...)
}

func Contains(Haystack []map[string]int, Needle map[string]int) bool{
    for _, val := range Haystack {
        if val["x"] == Needle["x"] && val["y"] == Needle["y"] {
            return true
        } else {}
    }    
    return false
}

func (p PlayerCharacter) CheckCollision(WallPositions []map[string]int) bool{ // FUA this should eventually take in a combined slice of wall positions of both inner and boundary walls
	for _, position := range WallPositions {
		if p.Position["x"] == position["x"] && p.Position["y"] == position["y"] {
			return true
		} else {}
	}
	return false
}