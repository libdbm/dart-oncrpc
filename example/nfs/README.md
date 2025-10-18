# NFS v3 Server Example

A complete, NFS v3 server implementation demonstrating the full capabilities of the `dart_oncrpc` library.

This example showcases:

- NFS v3 protocol implementation (RFC 1813)
- MOUNT v3 protocol for export management
- File handle generation and management
- XDR serialization/deserialization
- Multiple transport support (TCP/UDP)
- Portmapper integration
- Docker containerization for easy deployment
- macOS and Linux client compatibility

## Quick Start

### Option A: Docker (Recommended)

The easiest way to run the NFS server is using Docker:

```bash
cd example/nfs

# Build and run with docker-compose
docker-compose up -d

# Or build and run manually
docker build -t dart-nfs-server -f Dockerfile ../..
docker run -p 2049:2049 -v $(pwd)/export-content:/export:ro dart-nfs-server
```

The server will export the contents of the `export-content/` directory on port 2049.

**Mount on your host**:

```bash
# macOS
mkdir ~/nfs_mount
sudo mount -t nfs -o resvport,nolocks,vers=3 localhost:/ ~/nfs_mount
ls ~/nfs_mount

# Linux (requires nfs-common/nfs-utils package)
mkdir ~/nfs_mount
sudo mount -t nfs -o vers=3,nolocks localhost:/ ~/nfs_mount
ls ~/nfs_mount
```

See [Mounting the Docker NFS Server](#mounting-the-docker-nfs-server) section below for detailed instructions for both
macOS and Linux, including troubleshooting and mount options.

### Option B: Direct Execution

### 1. Generate Protocol Code

```bash
cd example/nfs
bash scripts/generate.sh
```

This generates `lib/nfs_types.dart` from the protocol definitions in `protocol/`.

### 2. Start the NFS Server

```bash
# Export the test_share directory
dart run bin/nfs_server.dart --export test_share

# Or export any directory
dart run bin/nfs_server.dart --export /path/to/your/directory
```

You should see output like:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  NFS v3 Server (dart_oncrpc example)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Export Configuration:
  Path:      /Users/you/dart-oncrpc/example/nfs/test_share
  Export:    /
  Mode:      read-write

Server Configuration:
  NFS Port:   2049
  MOUNT Port: (dynamic)
  Transport:  TCP
  Portmap:    disabled

Server Status: ✓ Running
```

### 3. Mount on macOS

In a new terminal:

```bash
# Option 1: Use the helper script
cd example/nfs
bash scripts/mount_macos.sh

# Option 2: Manual mount
mkdir ~/nfs_mount
sudo mount -t nfs -o resvport,nolocks,vers=3 localhost:/ ~/nfs_mount
```

### 4. Access Files

```bash
# List files
ls ~/nfs_mount

# Read a file
cat ~/nfs_mount/welcome.txt

# Create a file (if not read-only)
echo "Hello NFS" > ~/nfs_mount/test.txt

# Browse directories
cd ~/nfs_mount/documents
ls -la
```

### 5. Unmount When Done

```bash
# Option 1: Use the helper script
bash scripts/unmount_macos.sh

# Option 2: Manual unmount
sudo umount ~/nfs_mount
```

## Command-Line Options

```
Usage: dart run bin/nfs_server.dart [options]

Options:
  -e, --export <path>        Directory to export (required)
  -p, --port <port>          NFS server port (default: 2049)
  -m, --mount-port <port>    MOUNT server port (default: dynamic)
  -r, --read-only            Export as read-only
      --portmap              Register with portmapper on port 111
      --[no-]tcp             Use TCP transport (default: on)
      --udp                  Use UDP transport
  -v, --verbose              Verbose logging
  -h, --help                 Show this help message
```

### Examples

```bash
# Read-only export on custom port
dart run bin/nfs_server.dart --export /data --port 12049 --read-only

# With portmapper registration (requires root for port 111)
sudo dart run bin/nfs_server.dart --export /share --portmap

# TCP + UDP transports
dart run bin/nfs_server.dart --export . --tcp --udp
```

## Docker Deployment

### Building the Docker Image

The NFS server includes a multi-stage Dockerfile that creates an optimized container:

```bash
# From the project root or example/nfs directory
cd example/nfs

# Build using docker-compose (recommended)
docker-compose build

# Or build manually
docker build -t dart-nfs-server -f Dockerfile ../..
```

The Dockerfile uses a multi-stage build:

1. **Build stage**: Compiles Dart code to native executable
2. **Runtime stage**: Minimal Debian slim image with just the executable

This results in a small, secure container running as a non-root user.

### Running with Docker Compose

The easiest way to run the server:

```bash
# Start the server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

### Running with Docker CLI

```bash
# Run with default settings (exports ./export-content)
docker run -d \
  --name nfs-server \
  -p 2049:2049 \
  -v $(pwd)/export-content:/export:ro \
  dart-nfs-server

# Run with custom directory (read-write)
docker run -d \
  --name nfs-server \
  -p 2049:2049 \
  -v /path/to/your/data:/export \
  dart-nfs-server

# Run with custom port
docker run -d \
  --name nfs-server \
  -p 12049:12049 \
  dart-nfs-server \
  --export /export --port 12049 --tcp

# Run with verbose logging
docker run -d \
  --name nfs-server \
  -p 2049:2049 \
  -v $(pwd)/export-content:/export:ro \
  dart-nfs-server \
  --export /export --port 2049 --tcp --verbose
```

### Volume Mounting

The `-v` flag mounts host directories into the container:

```bash
# Read-only mount (recommended for serving static content)
-v /host/path:/export:ro

# Read-write mount (allows file creation/modification)
-v /host/path:/export

# Multiple volumes (if needed for logging, etc.)
-v $(pwd)/export-content:/export:ro \
-v $(pwd)/logs:/logs
```

**Important**: The container runs as user `nfsuser` (UID 1000). Ensure your host directory has appropriate permissions:

```bash
# Make directory readable by container user
chmod -R a+rX /path/to/export

# Or change ownership to UID 1000
sudo chown -R 1000:1000 /path/to/export
```

### Mounting the Docker NFS Server

Once the container is running, you can mount it from your host system. The process differs slightly between macOS and
Linux.

#### Mounting on macOS

macOS has built-in NFS client support with no additional software required.

**Prerequisites:**

- Docker container running and exposing port 2049
- Root/sudo access for mount operations

**Step-by-step:**

```bash
# 1. Ensure the container is running
docker compose ps
# Or: docker ps | grep nfs-server

# 2. Create mount point
mkdir ~/nfs_mount

# 3. Mount the NFS export
sudo mount -t nfs -o resvport,nolocks,vers=3 localhost:/ ~/nfs_mount

# 4. Verify mount
mount | grep nfs
df -h ~/nfs_mount

# 5. Access files
ls -la ~/nfs_mount
cat ~/nfs_mount/README.txt

# 6. Unmount when done
sudo umount ~/nfs_mount
```

**macOS Mount Options Explained:**

- `resvport` - Use reserved port (<1024) for client connection. Required by many NFS servers
- `nolocks` - Disable file locking (no lockd daemon needed)
- `vers=3` - Force NFS version 3 protocol
- Additional useful options:
    - `tcp` - Use TCP transport (default)
    - `ro` - Mount read-only
    - `soft` - Allow mount to timeout (vs `hard` which retries forever)
    - `timeo=10` - Set timeout to 1 second (value is in tenths)
    - `retrans=3` - Number of retransmissions before giving up

**Example with additional options:**

```bash
# Read-only mount with custom timeouts
sudo mount -t nfs -o resvport,nolocks,vers=3,ro,soft,timeo=10 localhost:/ ~/nfs_mount

# Using TCP explicitly
sudo mount -t nfs -o resvport,nolocks,vers=3,tcp localhost:/ ~/nfs_mount
```

**macOS via Finder (GUI Method):**

1. Open Finder
2. Press `⌘K` (or Go → Connect to Server)
3. Enter: `nfs://localhost/`
4. Click "Connect"
5. The share will mount under `/Volumes/`

**Troubleshooting macOS:**

```bash
# Check if NFS client is working
rpcinfo -p localhost

# Check mount status
mount | grep localhost

# Force unmount if stuck
sudo umount -f ~/nfs_mount

# If "Resource busy" error
lsof | grep nfs_mount  # Find processes using mount
cd ~                    # Change out of mount directory
sudo umount ~/nfs_mount
```

#### Mounting on Linux

Linux distributions include NFS client support, but may require installing client utilities.

**Prerequisites:**

**Debian/Ubuntu:**

```bash
sudo apt-get update
sudo apt-get install -y nfs-common
```

**RHEL/CentOS/Fedora:**

```bash
sudo dnf install -y nfs-utils
# Or on older systems: sudo yum install nfs-utils
```

**Arch Linux:**

```bash
sudo pacman -S nfs-utils
```

**Step-by-step:**

```bash
# 1. Ensure the container is running
docker compose ps

# 2. Create mount point
mkdir -p ~/nfs_mount

# 3. Mount the NFS export
sudo mount -t nfs -o vers=3,nolocks localhost:/ ~/nfs_mount

# 4. Verify mount
mount | grep nfs
df -h ~/nfs_mount

# 5. Access files
ls -la ~/nfs_mount
cat ~/nfs_mount/README.txt

# 6. Unmount when done
sudo umount ~/nfs_mount
```

**Linux Mount Options Explained:**

- `vers=3` - Use NFS version 3 (required)
- `nolocks` - Disable file locking
- Additional useful options:
    - `tcp` - Use TCP transport (default)
    - `udp` - Use UDP transport
    - `ro` - Mount read-only
    - `rw` - Mount read-write (default)
    - `soft` - Allow mount operations to timeout
    - `hard` - Retry mount operations indefinitely (default)
    - `timeo=14` - Set timeout to 1.4 seconds (value is in tenths)
    - `retrans=2` - Number of retries before error
    - `rsize=8192` - Read buffer size
    - `wsize=8192` - Write buffer size
    - `noatime` - Don't update access times (better performance)

**Example with additional options:**

```bash
# High-performance mount with large buffers
sudo mount -t nfs -o vers=3,nolocks,tcp,rsize=32768,wsize=32768,noatime localhost:/ ~/nfs_mount

# Read-only mount with soft timeout
sudo mount -t nfs -o vers=3,nolocks,ro,soft,timeo=10 localhost:/ ~/nfs_mount
```

**Persistent Mount (survives reboots):**

Add to `/etc/fstab`:

```bash
# Edit fstab (requires root)
sudo nano /etc/fstab

# Add this line:
localhost:/    /home/username/nfs_mount    nfs    vers=3,nolocks,_netdev    0    0

# The _netdev option ensures mount waits for network
# to be available before mounting
```

Mount from fstab:

```bash
sudo mount ~/nfs_mount
```

**Troubleshooting Linux:**

```bash
# Check NFS server is reachable
showmount -e localhost

# Check RPC services
rpcinfo -p localhost

# Check mount status
mount | grep nfs
cat /proc/mounts | grep nfs

# Enable verbose NFS debugging
sudo mount -v -t nfs -o vers=3,nolocks localhost:/ ~/nfs_mount

# Check system logs
sudo journalctl -xe | grep -i nfs
sudo dmesg | grep -i nfs

# Force unmount if stuck
sudo umount -f ~/nfs_mount

# Lazy unmount (if force fails)
sudo umount -l ~/nfs_mount

# If "Resource busy" error
lsof | grep nfs_mount
fuser -m ~/nfs_mount
```

#### Mounting from Remote Hosts

If the Docker host is on a different machine, replace `localhost` with the host's IP address:

**macOS:**

```bash
sudo mount -t nfs -o resvport,nolocks,vers=3 192.168.1.100:/ ~/nfs_mount
```

**Linux:**

```bash
sudo mount -t nfs -o vers=3,nolocks 192.168.1.100:/ ~/nfs_mount
```

**Important for remote access:**

- Ensure Docker port 2049 is accessible from client machine
- Check firewall rules on Docker host
- Consider security implications of exposing NFS

#### Common Issues Across Platforms

**"Connection refused"**

```bash
# Verify container is running
docker ps | grep nfs-server

# Verify port is exposed
docker port dart-nfs-server
# Should show: 2049/tcp -> 0.0.0.0:2049

# Check if port is listening
netstat -an | grep 2049
# Or: lsof -i :2049
```

**"Permission denied"**

```bash
# Check export permissions in container
docker exec dart-nfs-server ls -la /export

# Verify mount options include proper auth
# NFS uses UID/GID mapping - ensure host user has access
```

**"Stale file handle"**

```bash
# Unmount and remount
sudo umount ~/nfs_mount
sudo mount -t nfs -o vers=3,nolocks localhost:/ ~/nfs_mount

# This happens if:
# - Container was restarted
# - Export directory was moved/renamed
```

**"Program not registered" or "RPC: Program not registered"**

```bash
# Check container logs
docker logs dart-nfs-server

# Verify NFS server is running inside container
docker exec dart-nfs-server ps aux | grep nfs_server

# Restart container
docker compose restart
```

#### Testing the Mount

Once mounted, test basic operations:

```bash
# List files
ls -la ~/nfs_mount

# Read a file
cat ~/nfs_mount/README.txt

# Check filesystem info
df -h ~/nfs_mount
stat ~/nfs_mount

# Test write (if not mounted read-only)
echo "test" > ~/nfs_mount/test.txt
cat ~/nfs_mount/test.txt
rm ~/nfs_mount/test.txt

# Create directory
mkdir ~/nfs_mount/testdir
rmdir ~/nfs_mount/testdir

# Check permissions
touch ~/nfs_mount/permission_test
ls -l ~/nfs_mount/permission_test
rm ~/nfs_mount/permission_test
```

### Environment Variables

Configure the server using environment variables:

```bash
docker run -d \
  --name nfs-server \
  -p 2049:2049 \
  -v $(pwd)/export-content:/export:ro \
  -e EXPORT_DIR=/export \
  -e NFS_PORT=2049 \
  dart-nfs-server
```

Available variables:

- `EXPORT_DIR`: Directory to export (default: `/export`)
- `NFS_PORT`: NFS server port (default: `2049`)

## License

This example code follows the same license as the dart_oncrpc library.

## References

- [RFC 1813 - NFS Version 3 Protocol Specification](https://tools.ietf.org/html/rfc1813)
- [RFC 1094 - NFS: Network File System Protocol](https://tools.ietf.org/html/rfc1094)
- [RFC 5531 - RPC: Remote Procedure Call Protocol Specification Version 2](https://tools.ietf.org/html/rfc5531)
- [RFC 4506 - XDR: External Data Representation Standard](https://tools.ietf.org/html/rfc4506)
