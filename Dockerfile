FROM debian:stable-slim AS builder

# Install Zig
RUN apt-get update && apt-get install -y curl xz-utils && \
    curl -L https://ziglang.org/download/0.15.2/zig-x86_64-linux.tar.xz | tar xJ && \
    mv zig-* /opt/zig

WORKDIR /app
COPY . .

ENV PATH="/opt/zig:$PATH"
RUN zig build -Doptimize=ReleaseSafe

FROM debian:stable-slim

# Install CA certificates for outbound HTTPS (triggers)
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/zig-out/bin/buildlight /usr/local/bin/buildlight
# Copy public files for Fly.io [[statics]] to serve
COPY --from=builder /app/public /app/public

EXPOSE 8080
CMD ["buildlight"]
