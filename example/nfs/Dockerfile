# Multi-stage Dockerfile for NFS v3 Server
# Stage 1: Build the Dart application
FROM dart:stable AS build

WORKDIR /app

# Copy project root (for dart_oncrpc library)
COPY ../../ /dart-oncrpc/

# Set working directory to NFS example
WORKDIR /dart-oncrpc/example/nfs

# Get dependencies
RUN dart pub get

# Generate NFS protocol types
RUN bash scripts/generate.sh

# Compile to native executable for better performance
RUN dart compile exe bin/nfs_server.dart -o nfs_server

# Stage 2: Create minimal runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for running the server
RUN useradd -r -u 1000 -m -s /bin/bash nfsuser

# Create export directory
RUN mkdir -p /export && \
    chown nfsuser:nfsuser /export

# Copy compiled executable from build stage
COPY --from=build /dart-oncrpc/example/nfs/nfs_server /usr/local/bin/nfs_server
RUN chmod +x /usr/local/bin/nfs_server

# Copy default content to export (optional - will use empty directory if not present)
COPY --chown=nfsuser:nfsuser example/nfs/export-content/ /export/

# Switch to non-root user
USER nfsuser

# Expose NFS port (default 2049)
EXPOSE 2049

# Set default export directory
ENV EXPORT_DIR=/export
ENV NFS_PORT=2049

# Run the NFS server
ENTRYPOINT ["/usr/local/bin/nfs_server"]
CMD ["--export", "/export", "--port", "2049", "--tcp"]
