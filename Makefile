all: run

run:
	@go run ./src

test:
	@go test ./...

soak:
	@go test ./internal/game -run TestAutomatedSoakAcrossSeedsAndDifficulties

tidy:
	@go mod tidy

config:
	@printf "Install Go locally, then run 'make tidy' and 'make run'.\n"

clean:
	@go clean ./...
