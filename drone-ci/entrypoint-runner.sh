#!/bin/sh
set -e

# Start Docker daemon in background
dockerd --storage-driver=vfs &

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon..."
for i in $(seq 1 30); do
    if docker info > /dev/null 2>&1; then
        echo "Docker daemon is ready."
        break
    fi
    sleep 1
done

# Run the original runner binary
exec /bin/drone-runner-docker
