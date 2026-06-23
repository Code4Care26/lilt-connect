# --- build stage ---
# Pin to the Go version in go.mod (go 1.25). go-redis is pure Go, so we build a
# fully static binary (CGO_ENABLED=0) and drop it into a distroless image.
FROM golang:1.25 AS build
WORKDIR /src
# Cache the module download layer: deps change far less often than code.
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -o /gosse .

# --- runtime stage: minimal, just the static binary ---
# distroless/static has CA roots, which the rediss:// (TLS) client to Scaleway's
# managed Redis needs to verify the server certificate.
FROM gcr.io/distroless/static-debian12
COPY --from=build /gosse /gosse
# HOST/PORT/REDIS_URL/SSE_PUBLISH_SECRET are injected by the k8s manifest.
# In the cluster HOST must be 0.0.0.0 (the code default 127.0.0.1 is dev-only).
EXPOSE 3002
ENTRYPOINT ["/gosse"]
