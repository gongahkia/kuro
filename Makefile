all: build

build:src/main.go
	@go run src/main.go

config:
	@sudo apt upgrade && sudo apt update && sudo apt autoremove
	@sudo apt install golang

clean:
	@rm -rf .git .gitignore README.md

up:
	@git pull
	@git status