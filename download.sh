#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOWNLOADER_DIR="/hytale/downloader"
SERVER_DIR="/hytale/server"

echo -e "${BLUE}=== Hytale Server Downloader ===${NC}"
echo ""

# List what's in the downloader directory for debugging
echo "Checking downloader directory..."
ls -la "$DOWNLOADER_DIR/" 2>/dev/null || echo "Cannot list directory"
echo ""

# Find the downloader binary (try multiple possible names)
DOWNLOADER=""
for binary in "hytale-downloader-linux" "hytale-downloader-linux-amd64" "hytale-downloader-linux-x86_64" "hytale-downloader" "hytale-downloader-amd64"; do
    if [ -f "$DOWNLOADER_DIR/$binary" ]; then
        DOWNLOADER="$DOWNLOADER_DIR/$binary"
        echo -e "${GREEN}Found downloader binary: $binary${NC}"
        break
    fi
done

# If still not found, try to find any executable file
if [ -z "$DOWNLOADER" ]; then
    echo "Searching for any executable in downloader directory..."
    DOWNLOADER=$(find "$DOWNLOADER_DIR" -type f -executable -name "*downloader*" | head -n 1)
    if [ -n "$DOWNLOADER" ]; then
        echo -e "${GREEN}Found executable: $(basename $DOWNLOADER)${NC}"
    fi
fi

if [ -z "$DOWNLOADER" ] || [ ! -f "$DOWNLOADER" ]; then
    echo -e "${RED}ERROR: Hytale downloader binary not found!${NC}"
    echo "Checked in: $DOWNLOADER_DIR/"
    echo "Please check the Docker build logs or download manually."
    exit 1
fi

# Make sure it's executable
chmod +x "$DOWNLOADER" 2>/dev/null || true

# Change to server directory
cd "$SERVER_DIR"

# Version tracking file
VERSION_FILE="$SERVER_DIR/.hytale_version"

# Function to get the latest version from downloader
get_latest_version() {
    # Run downloader with -print-version flag to get latest available version
    "$DOWNLOADER" -print-version 2>/dev/null || echo "unknown"
}

# Determine if we need to download
NEED_DOWNLOAD=false

if [ -f "$SERVER_DIR/HytaleServer.jar" ] && [ -f "$SERVER_DIR/Assets.zip" ]; then
    echo -e "${YELLOW}Server files exist. Checking version...${NC}"

    # If HYTALE_VERSION is not set or is "latest", check for updates
    if [ -z "$HYTALE_VERSION" ] || [ "$HYTALE_VERSION" = "latest" ]; then
        echo "Version tracking: latest (auto-update mode)"

        # Get current version if tracked
        CURRENT_VERSION=""
        if [ -f "$VERSION_FILE" ]; then
            CURRENT_VERSION=$(cat "$VERSION_FILE")
            echo "Current version: $CURRENT_VERSION"

            # Check what the latest available version is
            echo "Checking for updates..."
            LATEST_VERSION=$(get_latest_version)

            if [ "$LATEST_VERSION" != "unknown" ] && [ -n "$LATEST_VERSION" ]; then
                echo "Latest version available: $LATEST_VERSION"

                if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
                    echo -e "${GREEN}Server is already up to date!${NC}"
                    NEED_DOWNLOAD=false
                else
                    echo -e "${YELLOW}New version available! $CURRENT_VERSION -> $LATEST_VERSION${NC}"
                    NEED_DOWNLOAD=true
                fi
            else
                # Can't determine latest version, download to be safe
                echo -e "${YELLOW}Cannot determine latest version, will re-download${NC}"
                NEED_DOWNLOAD=true
            fi
        else
            echo "No version file found - will download latest"
            NEED_DOWNLOAD=true
        fi
    else
        # Specific version requested - PINNED MODE
        echo "Version tracking: $HYTALE_VERSION (pinned)"

        if [ -f "$VERSION_FILE" ]; then
            CURRENT_VERSION=$(cat "$VERSION_FILE")
            if [ "$CURRENT_VERSION" = "$HYTALE_VERSION" ]; then
                echo -e "${GREEN}Server version matches pinned version: $HYTALE_VERSION${NC}"
                # Version matches, use existing files
                NEED_DOWNLOAD=false
            else
                echo -e "${RED}ERROR: Version mismatch!${NC}"
                echo "Current version: $CURRENT_VERSION"
                echo "Requested version: $HYTALE_VERSION"
                echo ""
                echo -e "${YELLOW}The Hytale downloader can only download the LATEST version.${NC}"
                echo "You have two options:"
                echo "1. Use the existing version by setting: HYTALE_VERSION=$CURRENT_VERSION"
                echo "2. Update to latest by setting: HYTALE_VERSION=latest"
                echo "3. Delete server files and download latest: rm -rf ./server/*"
                exit 1
            fi
        else
            # No version file - this means fresh download
            # Since we can only download latest, warn the user
            echo -e "${YELLOW}WARNING: No existing version found.${NC}"
            echo "The Hytale downloader can only download the LATEST version."
            echo "Requested pinned version: $HYTALE_VERSION"
            echo ""
            echo "Will download latest and tag it as version $HYTALE_VERSION"
            echo "This may not match the actual latest version number!"
            NEED_DOWNLOAD=true
        fi
    fi

    if [ "$NEED_DOWNLOAD" = false ]; then
        exit 0
    fi
else
    echo -e "${YELLOW}Server files not found. Downloading...${NC}"
    NEED_DOWNLOAD=true
fi

# Run the downloader
echo ""
echo -e "${BLUE}Running Hytale Downloader...${NC}"
echo "This may take a few minutes depending on your connection."
echo ""
echo -e "${YELLOW}IMPORTANT: Authentication required!${NC}"
echo "The downloader will prompt you to authenticate."
echo "Follow the instructions to visit the authentication URL."
echo ""

# Execute the downloader
if "$DOWNLOADER"; then
    echo ""
    echo -e "${GREEN}Download complete!${NC}"
    echo ""

    # The downloader creates a versioned ZIP file, we need to extract it
    # Find the downloaded ZIP file
    DOWNLOADED_ZIP=$(find "$SERVER_DIR" -maxdepth 1 -name "*.zip" -type f | head -n 1)

    if [ -n "$DOWNLOADED_ZIP" ] && [ -f "$DOWNLOADED_ZIP" ]; then
        # Extract version from ZIP filename (e.g., "2026.01.17-4b0f30090.zip")
        DOWNLOADED_VERSION=$(basename "$DOWNLOADED_ZIP" .zip)
        echo -e "${YELLOW}Extracting downloaded files from $DOWNLOADED_VERSION.zip...${NC}"

        # Extract the ZIP file directly to the server directory
        if unzip -o "$DOWNLOADED_ZIP" -d "$SERVER_DIR/"; then
            echo -e "${GREEN}Extraction complete!${NC}"
            echo ""

            # Move HytaleServer.jar from Server/ subdirectory to root if it exists
            if [ -f "$SERVER_DIR/Server/HytaleServer.jar" ]; then
                mv "$SERVER_DIR/Server/HytaleServer.jar" "$SERVER_DIR/"
                echo "Moved HytaleServer.jar to server directory"
            fi

            # Move HytaleServer.aot if it exists
            if [ -f "$SERVER_DIR/Server/HytaleServer.aot" ]; then
                mv "$SERVER_DIR/Server/HytaleServer.aot" "$SERVER_DIR/"
                echo "Moved HytaleServer.aot to server directory"
            fi

            # Create Assets.zip from all extracted content
            echo ""
            echo -e "${YELLOW}Creating Assets.zip from extracted files...${NC}"
            if cd "$SERVER_DIR" && zip -r Assets.zip Common/ Server/ Cosmetics/ manifest.json CommonAssetsIndex.hashes -q; then
                echo -e "${GREEN}Assets.zip created successfully!${NC}"
            else
                echo -e "${RED}Failed to create Assets.zip!${NC}"
                exit 1
            fi

            # Clean up extracted directories and downloaded ZIP
            rm -rf "$SERVER_DIR/Common" "$SERVER_DIR/Server" "$SERVER_DIR/Cosmetics" "$SERVER_DIR/manifest.json" "$SERVER_DIR/CommonAssetsIndex.hashes"
            rm "$DOWNLOADED_ZIP"
            echo "Cleaned up temporary files"
            echo ""
        else
            echo -e "${RED}Failed to extract downloaded ZIP file!${NC}"
            exit 1
        fi
    fi

    # Verify files exist
    if [ -f "$SERVER_DIR/HytaleServer.jar" ] && [ -f "$SERVER_DIR/Assets.zip" ]; then
        echo -e "${GREEN}✓ HytaleServer.jar found${NC}"
        echo -e "${GREEN}✓ Assets.zip found${NC}"

        # Show file sizes
        JAR_SIZE=$(du -h "$SERVER_DIR/HytaleServer.jar" | cut -f1)
        ASSETS_SIZE=$(du -h "$SERVER_DIR/Assets.zip" | cut -f1)
        echo ""
        echo "File sizes:"
        echo "  HytaleServer.jar: $JAR_SIZE"
        echo "  Assets.zip: $ASSETS_SIZE"

        # Save version information
        # DOWNLOADED_VERSION was extracted from the ZIP filename earlier
        if [ -n "$DOWNLOADED_VERSION" ]; then
            echo "$DOWNLOADED_VERSION" > "$VERSION_FILE"
            echo -e "${GREEN}Version $DOWNLOADED_VERSION saved to version file${NC}"
        else
            # Fallback: try to get version from downloader
            FALLBACK_VERSION=$("$DOWNLOADER" -print-version 2>/dev/null | tail -1 || echo "unknown")
            if [ "$FALLBACK_VERSION" != "unknown" ] && [ -n "$FALLBACK_VERSION" ]; then
                echo "$FALLBACK_VERSION" > "$VERSION_FILE"
                echo -e "${GREEN}Version $FALLBACK_VERSION saved to version file${NC}"
            else
                # Last resort: use timestamp
                echo "$(date +%Y%m%d-%H%M%S)" > "$VERSION_FILE"
                echo -e "${YELLOW}Version timestamp saved (actual version unknown)${NC}"
            fi
        fi

        exit 0
    else
        echo -e "${RED}ERROR: Server files not found after extraction!${NC}"
        echo "Checking what was extracted:"
        ls -lh "$SERVER_DIR/"
        exit 1
    fi
else
    echo -e "${RED}Download failed!${NC}"
    exit 1
fi
