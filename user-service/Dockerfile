# ---- Builder Stage ----
FROM golang:1.25.3-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN go build -o userService ./cmd

# ---- Lightweight Image ----
FROM alpine:3.22.2

WORKDIR /app

COPY --from=builder /app/userService .
COPY --from=builder /app/config ./config

EXPOSE 50051

CMD ["./userService"]
