# syntax=docker/dockerfile:1.7
FROM golang:1.22-alpine AS build
WORKDIR /src

# The api module imports the operator module via a `replace` directive that
# points at ../operator, so the build context must include both. Build with:
#   docker build -f api/Dockerfile -t pet-api .   (run from repo root)
COPY operator/ /src/operator/
COPY api/      /src/api/

WORKDIR /src/api
RUN go mod download || true
ENV CGO_ENABLED=0 GOOS=linux
RUN go build -trimpath -ldflags='-s -w' -o /out/pet-api ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /out/pet-api /pet-api
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/pet-api"]
