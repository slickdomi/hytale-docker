job "hytale-server" {
  # Region and datacenter configuration
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  # Update strategy
  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }

  group "hytale" {
    count = 1

    # Network configuration for UDP port
    network {
      port "game" {
        static = 5520
        to     = 5520
      }
    }

    # Volume configuration for persistent data
    volume "hytale-server" {
      type      = "host"
      source    = "hytale-server"
      read_only = false
    }

    volume "hytale-data" {
      type      = "host"
      source    = "hytale-data"
      read_only = false
    }

    # Restart policy
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    task "server" {
      driver = "docker"

      # Volume mounts
      volume_mount {
        volume      = "hytale-server"
        destination = "/hytale/server"
        read_only   = false
      }

      volume_mount {
        volume      = "hytale-data"
        destination = "/hytale/data"
        read_only   = false
      }

      config {
        image = "slickdomique/hytale-docker:latest"

        # UDP port mapping
        ports = ["game"]

        # Network mode
        network_mode = "bridge"

        # Enable TTY and stdin for authentication
        tty          = true
        interactive  = true
      }

      # Environment variables
      env {
        HYTALE_MAX_MEMORY     = "6G"
        HYTALE_PORT           = "5520"
        HYTALE_BIND           = "0.0.0.0"
        HYTALE_AOT_CACHE      = "true"
        HYTALE_AUTO_DOWNLOAD  = "true"
      }

      # Resource allocation - Small server (4-10 players)
      # Adjust based on your server size needs
      resources {
        cpu    = 4000  # 4 CPU cores
        memory = 4096  # 4GB RAM
      }

      # Service registration for discovery
      service {
        name = "hytale-server"
        port = "game"

        tags = [
          "game",
          "hytale",
          "udp"
        ]

        check {
          type     = "tcp"
          port     = "game"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
}