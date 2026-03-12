package main

import (
	"fmt"
	"os"

	"kuro/internal/game"
)

func main() {
	app, err := game.NewApp()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to start kuro: %v\n", err)
		os.Exit(1)
	}
	defer app.Close()

	if err := app.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "kuro exited with error: %v\n", err)
		os.Exit(1)
	}
}
