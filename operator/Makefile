.PHONY: tidy build test fmt vet lint docker

IMAGE ?= pet-operator:dev

tidy:
	go mod tidy

build:
	CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o bin/operator ./cmd

test:
	go test -race -count=1 -coverprofile=coverage.txt ./...

fmt:
	go fmt ./...

vet:
	go vet ./...

docker:
	docker build -t $(IMAGE) .
