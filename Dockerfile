FROM golang:1 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -tags production -o buildlight ./cmd/buildlight

FROM debian:stable-slim

COPY --from=builder /app/buildlight /usr/local/bin/buildlight

EXPOSE 8080
CMD ["buildlight"]
