# syntax=docker/dockerfile:1.7
# Multi-stage build: ~15 MB final image (distroless static).
FROM golang:1.22-alpine AS build
WORKDIR /src

# Cache deps separately from source for faster rebuilds.
COPY go.mod go.sum* ./
RUN go mod download || true

COPY . .
ENV CGO_ENABLED=0 GOOS=linux
RUN go build -trimpath -ldflags='-s -w' -o /out/operator ./cmd

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /out/operator /operator
USER 65532:65532
ENTRYPOINT ["/operator"]
