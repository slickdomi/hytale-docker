# Hytale Server Docker

A Docker container setup for running a Hytale dedicated server with Java 25 support.

Support discord at [hytale.works](https://discord.gg/6zZXJq7Zfb)

Available in dockerhub at [https://hub.docker.com/repository/docker/slickdomi/hytale-docker](https://hub.docker.com/repository/docker/slickdomi/hytale-docker)

After setting server up refer to **Server Authentication**

## Features

- **Automatic Server Download** - Downloads Hytale server files automatically on first run
- Java 25 JRE (required for Hytale)
- Support for both x64 and arm64 architectures
- Persistent data storage (world saves, configs, logs, mods)
- Configurable memory allocation
- AOT (Ahead-of-Time) caching support for better performance
- UDP port mapping for QUIC protocol
- Easy deployment with Docker Compose

## System Requirements

Based on official Hytale documentation:

### Minimum Requirements
- 6GB RAM
- 4 CPU cores
- Java 25
- UDP port 5520 (or custom port)

### Recommended by Server Size

| Server Size | Players | CPU Cores | RAM | View Distance |
|------------|---------|-----------|-----|---------------|
| Small | 2-5 | 4 | 6-8 GB | 12 chunks |
| Medium | 5-30 | 6 | 8-10 GB | 12 chunks |
| Large | 50+ | 8+ | 12+ GB | 10-12 chunks |

## Quick Start

### Method 1: Using Pre-built Image (Easiest)

Use the pre-built image from Docker Hub:

```bash
# Create directories
mkdir -p server data

# Create a docker-compose.yml file
cat > docker-compose.yml << 'EOF'
services:
  hytale:
    image: slickdomi/hytale-docker:latest
    container_name: hytale-server
    restart: unless-stopped
    ports:
      - "5520:5520/udp"
    volumes:
      - ./server:/hytale/server
      - ./data:/hytale/data
    environment:
      - HYTALE_MAX_MEMORY=6G
      - HYTALE_AUTO_DOWNLOAD=true
    stdin_open: true
    tty: true
EOF

# Start the server
docker compose up -d

# Watch the logs
docker compose logs -f
```

The container will automatically download the server files and prompt you for authentication!

### Method 2: Building from Source

If you want to build the image yourself:

1. Clone this repository:
```bash
git clone https://github.com/SlickDomi/hytale-docker.git
cd hytale-docker
```

2. Create the required directories:
```bash
mkdir -p server data
```

3. Build and start the container:
```bash
docker compose build
docker compose up -d
```

4. Watch the logs to follow the download progress:
```bash
docker compose logs -f
```

The server will download the files and then prompt you for authentication.

### Method 3: Manual Server Files

If you prefer to provide the server files manually:

**Option A: Copy from your Hytale installation**
```bash
# Windows
copy %appdata%\Hytale\install\release\package\game\latest\Server\* ./server/
copy %appdata%\Hytale\install\release\package\game\latest\Assets.zip ./server/
```

**Option B: Use Hytale Downloader CLI**
```bash
# Download and use the official Hytale Downloader
curl -O https://downloader.hytale.com/hytale-downloader.zip
unzip hytale-downloader.zip
./hytale-downloader-linux
# Copy downloaded files to ./server/
```

**Then disable auto-download and start the container:**
```bash
# In docker-compose.yml, set:
# - HYTALE_AUTO_DOWNLOAD=false

docker-compose up -d
```

### Server Authentication

After starting the server for the first time, you need to authenticate it:

1. Attach to the container console:
```bash
docker attach hytale-server
```

2. Run the authentication command:
```
/auth login device
```

3. Follow the on-screen instructions to authenticate with your Hytale account.

4. Run the command to set the storage of secrets
```
/auth persistence Encrypted
```

5. Detach from the console: Press `Ctrl+P` then `Ctrl+Q`

## Configuration

### Environment Variables

Edit the `docker-compose.yml` or create a `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `HYTALE_AUTO_DOWNLOAD` | `true` | Automatically download server files on first run |
| `HYTALE_VERSION` | `""` (latest) | Server version control - see [Version Control](#version-control) below |
| `HYTALE_MAX_MEMORY` | `6G` | Maximum memory allocation (6G, 8G, 12G, etc.) |
| `HYTALE_PORT` | `5520` | Server port (UDP) |
| `HYTALE_BIND` | `0.0.0.0` | Bind address (0.0.0.0 for all interfaces) |
| `HYTALE_AOT_CACHE` | `true` | Enable AOT caching for performance |
| `JAVA_OPTS` | Empty | Additional Java options |

### Version Control

Control which server version to run and whether to auto-update:

**Auto-update mode (default):**
```yaml
environment:
  # Leave unset or set to "latest" to always get the newest version
  - HYTALE_VERSION=latest
  # or simply omit the variable entirely
```

When `HYTALE_VERSION` is unset or set to `"latest"`:
- On first start: Downloads the latest server version
- On restart: Checks for updates and downloads if a new version is available
- Won't re-download if you already have the current latest version
- Version is automatically detected from the downloaded ZIP filename

**Pin to specific version:**
```yaml
environment:
  # Pin to a specific version - prevents auto-updates
  - HYTALE_VERSION=2026.01.17-4b0f30090
```

When set to a specific version:
- Uses existing server files if they match the pinned version
- **Prevents downloading updates** - if versions don't match, shows an error
- Useful for production servers that need stability
- **Note**: The Hytale downloader can only download "latest", so you must already have the pinned version downloaded

**Important Notes:**
- The Hytale downloader CLI only supports downloading the "latest" version
- You cannot download old/specific versions - pinning only prevents updates
- To get the version number: Check your logs after download or look at the ZIP filename
- Version format example: `2026.01.17-4b0f30090`

**Version tracking:**
- The current version is stored in `/hytale/server/.hytale_version`
- This file persists in your `./server` volume
- Delete this file to force a re-download on next restart

**Example workflow for version pinning:**
```bash
# 1. Start with latest
docker compose up -d

# 2. Check what version was downloaded
docker compose logs | grep "Version"
# Output: Version 2026.01.17-4b0f30090 saved to version file

# 3. Pin to that version in docker-compose.yml
environment:
  - HYTALE_VERSION=2026.01.17-4b0f30090

# 4. Restart - will use existing files, won't update
docker compose restart
```

### Memory Recommendations

Adjust `HYTALE_MAX_MEMORY` based on your server size:

```yaml
# Small server (2-5 players)
- HYTALE_MAX_MEMORY=6G

# Medium server (20-30 players)
- HYTALE_MAX_MEMORY=8G

# Large server (50+ players)
- HYTALE_MAX_MEMORY=12G
```

### Port Configuration

The default port is 5520 (UDP). To change it:

```yaml
ports:
  - "25565:25565/udp"  # Change both host and container port
environment:
  - HYTALE_PORT=25565
```

### Server Configuration Files

Configuration files are stored in the `data/` directory:

- `config.json` - Main server configuration
- `permissions.json` - Player permissions
- `whitelist.json` - Whitelisted players
- `bans.json` - Banned players

An example `config.example.json` is provided as a reference.

## Directory Structure

```
hytale-docker/
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
├── entrypoint.sh          # Container startup script
├── .env.example           # Example environment variables
├── config.example.json    # Example server configuration
├── server/                # Mount point for server files
│   ├── HytaleServer.jar   # (You provide this)
│   └── Assets.zip         # (You provide this)
└── data/                  # Persistent data (auto-created)
    ├── .cache/           # Optimized file cache
    ├── logs/             # Server logs
    ├── mods/             # Server mods
    ├── universe/         # World saves
    ├── config.json       # Server config
    ├── permissions.json  # Permissions
    ├── whitelist.json    # Whitelist
    └── bans.json         # Bans list
```

## Docker Commands

### Start the server
```bash
docker-compose up -d
```

### Stop the server
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f
```

### Attach to console
```bash
docker attach hytale-server
# Detach: Ctrl+P then Ctrl+Q
```

### Restart the server
```bash
docker-compose restart
```

### Rebuild the image
```bash
docker-compose build --no-cache
docker-compose up -d
```

## Networking

### Port Forwarding

If hosting behind a router, forward UDP port 5520 (or your custom port) to your server machine.

Hytale uses the **QUIC protocol over UDP**, not TCP. Ensure your firewall allows UDP traffic on the configured port.

### Firewall Configuration

```bash
# Allow UDP port 5520
sudo ufw allow 5520/udp

# For custom port
sudo ufw allow <your-port>/udp
```

## Performance Optimization

### View Distance

The recommended view distance is **12 chunks (384 blocks)** for optimal performance. This can be configured in `config.json`:

```json
{
  "server": {
    "viewDistance": 12
  }
}
```

Doubling the view distance quadruples the computational load. Lower values improve performance on limited hardware.

### Java Options

Add custom Java options for performance tuning:

```yaml
environment:
  - JAVA_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=50
```

### Resource Limits

Limit container resources in `docker-compose.yml`:

```yaml
services:
  hytale:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 6G
```

## Authentication

Hytale servers require authentication to communicate with service APIs. Each Hytale game license allows up to **100 servers**.

When the server starts, it will automatically display an authentication URL in the logs. Watch the logs to see the authentication prompt:

```bash
docker compose logs -f
```

You'll see output like:
```
Please visit the following URL to authenticate:
https://oauth.accounts.hytale.com/oauth2/device/verify?user_code=XXXXXXXX
```

Simply visit that URL in your browser and authorize the server. The server will automatically detect the authentication and continue starting up.

**Note**: You will need to authenticate each time you create a new server instance or when the authentication expires.

## Backup

To backup your server data:

```bash
# Create backup
tar -czf hytale-backup-$(date +%Y%m%d).tar.gz data/

# Restore backup
tar -xzf hytale-backup-YYYYMMDD.tar.gz
```

## Updating

To update to a new Hytale server version:

1. Stop the container:
```bash
docker-compose down
```

2. Replace server files in `server/` directory with new versions

3. Rebuild and start:
```bash
docker-compose build --no-cache
docker-compose up -d
```

## License

This Docker configuration is provided as-is. Hytale is property of Hypixel Studios. Ensure you comply with Hytale's Terms of Service and EULA.

## Resources

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Hytale Downloader](https://downloader.hytale.com/hytale-downloader.zip)
- [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)

## Support

For Hytale server issues, refer to the official Hytale support documentation.

For Docker-specific issues, please open an issue in this repository.
