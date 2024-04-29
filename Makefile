all: build

build:src/main.go
	@go run src/main.go

config:
	@go build

clean:
	rm -rf .git .gitignore README.md
