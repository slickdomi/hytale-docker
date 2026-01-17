FROM eclipse-temurin:25-jre-noble

# Install curl and other utilities
RUN apt-get update && \
    apt-get install -y curl unzip zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create server directory
WORKDIR /hytale

# Create necessary directories
RUN mkdir -p /hytale/server /hytale/data /hytale/downloader

# Download and extract Hytale Downloader
RUN curl -L -o /hytale/downloader/hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip && \
    cd /hytale/downloader && \
    unzip hytale-downloader.zip && \
    rm hytale-downloader.zip && \
    echo "Contents of downloader directory:" && \
    ls -la /hytale/downloader/ && \
    chmod +x /hytale/downloader/* 2>/dev/null || true

# Set up volumes for persistent data
VOLUME ["/hytale/data"]

# Expose the default Hytale server port (UDP)
EXPOSE 5520/udp

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY download.sh /download.sh
RUN chmod +x /entrypoint.sh /download.sh

# Set working directory to server
WORKDIR /hytale/server

# Default environment variables
ENV HYTALE_MAX_MEMORY=6G \
    HYTALE_PORT=5520 \
    HYTALE_BIND=0.0.0.0 \
    HYTALE_AOT_CACHE=true \
    HYTALE_VIEW_DISTANCE=12 \
    HYTALE_AUTO_DOWNLOAD=true \
    HYTALE_VERSION="" \
    JAVA_OPTS=""

ENTRYPOINT ["/entrypoint.sh"]
