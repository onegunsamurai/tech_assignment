.PHONY: tidy build test fmt vet docker

IMAGE ?= pet-api:dev

tidy:
	go mod tidy

build:
	CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o bin/pet-api ./cmd/server

test:
	go test -race -count=1 -coverprofile=coverage.txt ./...

fmt:
	go fmt ./...

vet:
	go vet ./...

docker:
	docker build -f Dockerfile -t $(IMAGE) ..
