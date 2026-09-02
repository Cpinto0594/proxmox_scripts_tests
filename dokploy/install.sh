PORT=3001

#!/bin/bash
install_dokploy() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi

    # check if is Mac OS
    if [ "$(uname)" = "Darwin" ]; then
        echo "This script must be run on Linux" >&2
        exit 1
    fi

    # check if is running inside a container
    if [ -f /.dockerenv ]; then
        echo "This script must be run on Linux" >&2
        exit 1
    fi

    # check if something is running on port 80
    if ss -tulnp | grep ':80 ' >/dev/null; then
        echo "Error: something is already running on port 80" >&2
        exit 1
    fi

    # check if something is running on port 443
    if ss -tulnp | grep ':443 ' >/dev/null; then
        echo "Error: something is already running on port 443" >&2
        exit 1
    fi

    # check if something is running on port $PORT
    if ss -tulnp | grep ':$PORT ' >/dev/null; then
        echo "Error: something is already running on port $PORT" >&2
        echo "Dokploy requires port $PORT to be available. Please stop any service using this port." >&2
        exit 1
    fi

    command_exists() {
      command -v "$@" > /dev/null 2>&1
    }

    if command_exists docker; then
      echo "Docker already installed"
    else
      curl -sSL https://get.docker.com | sh
    fi

    #docker swarm leave --force 2>/dev/null

    get_ip() {
        local ip=""
        
        # Try IPv4 first
        # First attempt: ifconfig.io
        ip=$(curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null)
        
        # Second attempt: icanhazip.com
        if [ -z "$ip" ]; then
            ip=$(curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
        fi
        
        # Third attempt: ipecho.net
        if [ -z "$ip" ]; then
            ip=$(curl -4s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
        fi

        # If no IPv4, try IPv6
        if [ -z "$ip" ]; then
            # Try IPv6 with ifconfig.io
            ip=$(curl -6s --connect-timeout 5 https://ifconfig.io 2>/dev/null)
            
            # Try IPv6 with icanhazip.com
            if [ -z "$ip" ]; then
                ip=$(curl -6s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
            fi
            
            # Try IPv6 with ipecho.net
            if [ -z "$ip" ]; then
                ip=$(curl -6s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)
            fi
        fi

        if [ -z "$ip" ]; then
            echo "Error: Could not determine server IP address automatically (neither IPv4 nor IPv6)." >&2
            echo "Please set the ADVERTISE_ADDR environment variable manually." >&2
            echo "Example: export ADVERTISE_ADDR=<your-server-ip>" >&2
            exit 1
        fi

        echo "$ip"
    }

    advertise_addr="${ADVERTISE_ADDR:-$(get_ip)}"
    echo "Using advertise address: $advertise_addr"

    #docker swarm init --advertise-addr 127.0.0.1 --listen-addr 127.0.0.1:2377
    
     if [ $? -ne 0 ]; then
        echo "Error: Failed to initialize Docker Swarm" >&2
        exit 1
    fi

    echo "Swarm initialized"

    docker network rm -f dokploy-network 2>/dev/null
    docker network create --driver overlay --attachable dokploy-network

    echo "Network created"

    mkdir -p /etc/dokploy

    chmod 777 /etc/dokploy

    # Generate secure random password for Postgres
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

    #docker secret rm dokploy_postgres_password   # fails if a service still references it — remove/stop that service first
    #echo -n "the_old_password" | docker secret create dokploy_postgres_password -
    #docker service update --force dokploy
    
    # Store password as Docker Secret (encrypted and secure)
    echo "$POSTGRES_PASSWORD" | docker secret create dokploy_postgres_password - 2>/dev/null || true
    
    echo "Generated secure database credentials (stored in Docker Secrets)"

    DOKPLOY_DATA_DIR_LOCAL=/home/carlosp/projects/dokploy-data
    POSTGRESQL_DATA_DIR_LOCAL="$DOKPLOY_DATA_DIR_LOCAL/postgres"

    # copy existing volume data to a host path
    mkdir -p "$POSTGRESQL_DATA_DIR_LOCAL"
    docker run --rm \
    -v dokploy-postgres:/from \
    -v "$POSTGRESQL_DATA_DIR_LOCAL":/to \
    alpine sh -c "cp -av /from/. /to/"

 docker service create \
    --name dokploy-postgres \
    --constraint 'node.role==manager' \
    --network dokploy-network \
    --env POSTGRES_USER=dokploy \
    --env POSTGRES_DB=dokploy \
    --secret source=dokploy_postgres_password,target=/run/secrets/postgres_password \
    --env POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
    --mount type=volume,source=dokploy-postgres,target=/var/lib/postgresql/data \
    postgres:16

    # Installation
    docker service create \
      --name dokploy \
      --replicas 1 \
      --network dokploy-network \
      --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
      --mount type=bind,source=/etc/dokploy,target=/etc/dokploy \
      --mount type=volume,source=dokploy,target=/root/.docker \
      --secret source=dokploy_postgres_password,target=/run/secrets/postgres_password \
      --publish published=3001,target=3000,mode=host \
      --update-parallelism 1 \
      --update-order stop-first \
      --constraint 'node.role == manager' \
      -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
      dokploy/dokploy:latest


    docker run -d \
        --name dokploy-traefik \
        --restart always \
        -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml \
        -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -p 80:80/tcp \
        -p 443:443/tcp \
        -p 443:443/udp \
        traefik:v3.6.7

    docker network connect dokploy-network dokploy-traefik


    # Optional: Use docker service create instead of docker run
    #   docker service create \
    #     --name dokploy-traefik \
    #     --constraint 'node.role==manager' \
    #     --network dokploy-network \
    #     --mount type=bind,source=/etc/dokploy/traefik/traefik.yml,target=/etc/traefik/traefik.yml \
    #     --mount type=bind,source=/etc/dokploy/traefik/dynamic,target=/etc/dokploy/traefik/dynamic \
    #     --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock,readonly \
    #     --publish mode=host,published=443,target=443 \
    #     --publish mode=host,published=80,target=80 \
    #     --publish mode=host,published=443,target=443,protocol=udp \
    #     traefik:v3.6.7

    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[0;34m"
    NC="\033[0m" # No Color

    format_ip_for_url() {
        local ip="$1"
        if echo "$ip" | grep -q ':'; then
            # IPv6
            echo "[${ip}]"
        else
            # IPv4
            echo "${ip}"
        fi
    }

    formatted_addr=$(format_ip_for_url "$advertise_addr")
    echo ""
    printf "${GREEN}Congratulations, Dokploy is installed!${NC}\n"
    printf "${BLUE}Wait 15 seconds for the server to start${NC}\n"
    printf "${YELLOW}Please go to http://${formatted_addr}:$PORT${NC}\n\n"
}

update_dokploy() {
    echo "Updating Dokploy..."
    
    # Pull the latest image
    docker pull dokploy/dokploy:latest

    # Update the service
    docker service update --image dokploy/dokploy:latest dokploy

    echo "Dokploy has been updated to the latest version."
}

unisntall_dokploy(){
    echo "Uninstalling"
    # 1. Remove the main Dokploy service
    docker service rm dokploy

    # 2. Remove Postgres and Redis services
    docker service rm dokploy-postgres
    docker service rm dokploy-redis

    # 3. Remove Traefik (this one is a plain container, not a swarm service)
    docker rm -f dokploy-traefik

    # 4. Remove the overlay network
    docker network rm dokploy-network

    # 5. Check what volumes exist before deleting
    docker volume ls | grep dokploy

    # 6. Remove the volumes (adjust names to match what step 5 showed)
    docker volume rm dokploy-postgres
    docker volume rm dokploy          # this backs /root/.docker
    docker volume rm dokploy-redis-data   # if it exists

    # 7. Remove the config directory
    sudo rm -rf /etc/dokploy

}

# Main script execution
if [ "$1" = "update" ]; then
    update_dokploy
elif [ "$1" = "uninstall" ]; then
    unisntall_dokploy
else
    install_dokploy
fi