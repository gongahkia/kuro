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