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
        fmt.Println("Error hit while reading input:", err)
        return 0
    }
    return char
}
