#!/bin/bash

set -e

# Configuration
CONTAINER_NAME="mongodb"
MONGO_PORT="27017"
MONGO_VERSION="latest"
DB_NAME="mydb"
DB_USER="mcp-client-user"
CREDENTIALS_FILE="./mongodb_credentials.txt"

# Generate random password (16 characters, alphanumeric)
DB_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)

echo "=== MongoDB Docker Setup ==="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Docker is not running. Attempting to start Docker..."

    # Try to start Docker based on the system
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open -a Docker
        echo "Waiting for Docker to start..."
        while ! docker info &> /dev/null; do
            sleep 2
        done
        echo "Docker started successfully!"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v systemctl &> /dev/null; then
            sudo systemctl start docker
            echo "Docker started successfully!"
        else
            echo "Error: Cannot start Docker automatically. Please start Docker manually."
            exit 1
        fi
    else
        echo "Error: Cannot start Docker automatically on this OS. Please start Docker manually."
        exit 1
    fi
else
    echo "Docker is already running."
fi

echo ""

# Check if MongoDB container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "MongoDB container '${CONTAINER_NAME}' already exists."

    # Check if it's running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container is already running."
    else
        echo "Starting existing container..."
        docker start ${CONTAINER_NAME}
    fi
else
    echo "Creating and starting new MongoDB container..."
    docker run -d \
        --name ${CONTAINER_NAME} \
        -p ${MONGO_PORT}:27017 \
        -e MONGO_INITDB_ROOT_USERNAME=admin \
        -e MONGO_INITDB_ROOT_PASSWORD=admin123 \
        mongo:${MONGO_VERSION}

    echo "Waiting for MongoDB to be ready..."
    sleep 10
fi

echo ""
echo "=== Creating Database User ==="

# Create user with readWrite permissions
docker exec -i ${CONTAINER_NAME} mongosh admin --quiet <<EOF
db.auth('admin', 'admin123');

// Switch to the database
use ${DB_NAME};

// Create user with readWrite role
db.createUser({
  user: '${DB_USER}',
  pwd: '${DB_PASSWORD}',
  roles: [
    { role: 'readWrite', db: '${DB_NAME}' }
  ]
});

print('User created successfully!');
EOF

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "MongoDB is running on localhost:${MONGO_PORT}"
echo ""
echo "Connection Details:"
echo "-------------------"
echo "Host: localhost"
echo "Port: ${MONGO_PORT}"
echo "Database: ${DB_NAME}"
echo "Username: ${DB_USER}"
echo "Password: ${DB_PASSWORD}"
echo ""
echo "Connection String:"
echo "mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${MONGO_PORT}/${DB_NAME}?authSource=${DB_NAME}"
echo ""

# Save credentials to file
cat > ${CREDENTIALS_FILE} <<EOF
MongoDB Connection Details
==========================
Host: localhost
Port: ${MONGO_PORT}
Database: ${DB_NAME}
Username: ${DB_USER}
Password: ${DB_PASSWORD}

Connection String:
mongodb://${DB_USER}:${DB_PASSWORD}@localhost:${MONGO_PORT}/${DB_NAME}?authSource=${DB_NAME}

Admin Credentials (for management):
Username: admin
Password: admin123
EOF

echo "Credentials saved to: ${CREDENTIALS_FILE}"
echo ""

# Deploy MongoDB MCP Server
MCP_CONTAINER_NAME="mongodb-mcp-server"
MCP_PORT="3000"

echo "=== Deploying MongoDB MCP Server ==="
echo ""

# Check if MCP server container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${MCP_CONTAINER_NAME}$"; then
    echo "MongoDB MCP Server container '${MCP_CONTAINER_NAME}' already exists."

    # Check if it's running
    if docker ps --format '{{.Names}}' | grep -q "^${MCP_CONTAINER_NAME}$"; then
        echo "Container is already running. Stopping it to update configuration..."
        docker stop ${MCP_CONTAINER_NAME}
        docker rm ${MCP_CONTAINER_NAME}
    else
        echo "Removing stopped container..."
        docker rm ${MCP_CONTAINER_NAME}
    fi
fi

echo "Starting MongoDB MCP Server..."

# Build the connection string for the MCP server
# Use host.docker.internal to connect from container to host on Mac/Windows
# Use 172.17.0.1 (Docker bridge IP) for Linux
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys" ]]; then
    MONGO_HOST="host.docker.internal"
else
    MONGO_HOST="172.17.0.1"
fi

MONGO_URI="mongodb://${DB_USER}:${DB_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${DB_NAME}?authSource=${DB_NAME}"

docker run -d \
    --name ${MCP_CONTAINER_NAME} \
    -p ${MCP_PORT}:3000 \
    -e MONGODB_URI="${MONGO_URI}" \
    -e MDB_MCP_READ_ONLY="true" \
    docker run --rm -i \
    mongodb/mongodb-mcp-server:latest

if [ $? -eq 0 ]; then
    echo ""
    echo "=== MongoDB MCP Server Deployed! ==="
    echo ""
    echo "MCP Server is running on localhost:${MCP_PORT}"
    echo ""
else
    echo ""
    echo "Warning: Failed to start MongoDB MCP Server."
    echo "Make sure the 'mongodb-mcp-server:latest' image exists."
    echo "You may need to build or pull the image first."
    echo ""
fi

echo "=== Complete Setup Summary ==="
echo ""
echo "MongoDB:"
echo "  - Container: ${CONTAINER_NAME}"
echo "  - Port: ${MONGO_PORT}"
echo "  - Status: Running"
echo ""
echo "MongoDB MCP Server:"
echo "  - Container: ${MCP_CONTAINER_NAME}"
echo "  - Port: ${MCP_PORT}"
echo "  - Status: Check with 'docker ps'"
echo ""
echo "To stop services:"
echo "  docker stop ${CONTAINER_NAME} ${MCP_CONTAINER_NAME}"
echo ""
echo "To remove services:"
echo "  docker rm -f ${CONTAINER_NAME} ${MCP_CONTAINER_NAME}"