package utils

import (
    "bufio"
    "fmt"
    "os"
    "math"
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

func CombineWallSlices(WallPositions1 []map[string]int, WallPositions2 []map[string]int) []map[string]int{
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

func ColumnRowProximity(Haystack []map[string]int, Needle map[string]int, tolerance int) bool{
    for _,val := range Haystack {
        if math.Abs(float64(val["x"] - Needle["x"])) < float64(tolerance) || math.Abs(float64(val["y"] - Needle["y"])) < float64(tolerance) {
            return true
        } else {}
    }
    return false
}