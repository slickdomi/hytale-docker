#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Hytale Server Docker Container ===${NC}"
echo ""

# Check if auto-download is enabled and server files don't exist
if [ "$HYTALE_AUTO_DOWNLOAD" = "true" ]; then
    if [ ! -f "/hytale/server/HytaleServer.jar" ] || [ ! -f "/hytale/server/Assets.zip" ]; then
        echo -e "${YELLOW}Auto-download enabled. Downloading server files...${NC}"
        echo ""

        # Run the download script
        if /download.sh; then
            echo ""
            echo -e "${GREEN}Server files downloaded successfully!${NC}"
            echo ""
        else
            echo -e "${RED}Failed to download server files!${NC}"
            echo ""
            echo -e "${YELLOW}You can manually provide server files by:${NC}"
            echo "1. Mounting them: -v /path/to/server:/hytale/server"
            echo "2. Disabling auto-download: -e HYTALE_AUTO_DOWNLOAD=false"
            echo ""
            exit 1
        fi
    else
        echo -e "${GREEN}Server files already present. Skipping download.${NC}"
        echo ""
    fi
fi

# Verify server files exist
if [ ! -f "/hytale/server/HytaleServer.jar" ]; then
    echo -e "${RED}ERROR: HytaleServer.jar not found!${NC}"
    echo -e "${YELLOW}Please mount your Hytale server files to /hytale/server${NC}"
    echo "Example: docker run -v /path/to/server:/hytale/server ..."
    echo ""
    echo "To obtain the server files, you can:"
    echo "1. Enable auto-download: -e HYTALE_AUTO_DOWNLOAD=true"
    echo "2. Copy from your Hytale installation at: %appdata%\Hytale\install\release\package\game\latest"
    echo "3. Use the Hytale Downloader: https://downloader.hytale.com/hytale-downloader.zip"
    exit 1
fi

if [ ! -f "/hytale/server/Assets.zip" ]; then
    echo -e "${RED}ERROR: Assets.zip not found!${NC}"
    echo -e "${YELLOW}Please mount your Hytale assets to /hytale/server${NC}"
    exit 1
fi

# Create symbolic links for data directory if they don't exist
DATA_DIR="/hytale/data"
mkdir -p "$DATA_DIR"/{.cache,.secrets,logs,mods,universe}

# Link persistent directories (including .secrets for auth persistence)
for dir in .cache .secrets logs mods universe config.json permissions.json whitelist.json bans.json; do
    if [ -e "/hytale/server/$dir" ] && [ ! -L "/hytale/server/$dir" ]; then
        echo "Moving existing $dir to data directory..."
        mv "/hytale/server/$dir" "$DATA_DIR/" 2>/dev/null || true
    fi

    if [ ! -e "/hytale/server/$dir" ]; then
        if [ -d "$DATA_DIR/$dir" ] || [ -f "$DATA_DIR/$dir" ]; then
            ln -sf "$DATA_DIR/$dir" "/hytale/server/$dir"
        fi
    fi
done

# Build Java command
JAVA_CMD="java"

# Add memory settings
JAVA_CMD="$JAVA_CMD -Xmx${HYTALE_MAX_MEMORY}"

# Add AOT cache if enabled
if [ "$HYTALE_AOT_CACHE" = "true" ]; then
    JAVA_CMD="$JAVA_CMD -XX:AOTCache=HytaleServer.aot"
fi

# Add custom Java options
if [ -n "$JAVA_OPTS" ]; then
    JAVA_CMD="$JAVA_CMD $JAVA_OPTS"
fi

# Add server jar
JAVA_CMD="$JAVA_CMD -jar HytaleServer.jar"

# Add assets
JAVA_CMD="$JAVA_CMD --assets Assets.zip"

# Add bind address and port
JAVA_CMD="$JAVA_CMD --bind ${HYTALE_BIND}:${HYTALE_PORT}"

echo -e "${GREEN}Starting Hytale Server...${NC}"
echo "Command: $JAVA_CMD"
echo "Memory: ${HYTALE_MAX_MEMORY}"
echo "Port: ${HYTALE_PORT} (UDP)"
echo "Bind: ${HYTALE_BIND}"
echo ""
echo -e "${YELLOW}IMPORTANT: After first authentication, you MUST run:${NC}"
echo -e "${YELLOW}  1. /auth login device${NC}"
echo -e "${YELLOW}  2. /auth persistence Encrypted${NC}"
echo -e "${YELLOW}This ensures your authentication persists across restarts!${NC}"
echo ""

# Execute the server
exec $JAVA_CMD
