#!/bin/bash

# Script to start n8n and n8n-mcp server for use with Claude Code
set -e

# Check for command line arguments
if [ "$1" == "--clear-api-key" ] || [ "$1" == "-c" ]; then
    echo "🗑️  Clearing saved n8n API key..."
    rm -f "$HOME/.n8n-mcp-test/.n8n-api-key"
    echo "✅ API key cleared. You'll be prompted for a new key on next run."
    exit 0
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -c, --clear-api-key  Clear the saved n8n API key"
    echo ""
    echo "The script will save your n8n API key on first use and reuse it on"
    echo "subsequent runs. You can override the saved key at runtime or clear"
    echo "it with the --clear-api-key option."
    exit 0
fi

echo "🚀 Starting n8n and n8n-mcp server for Claude Code..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
N8N_PORT=5678

# n8n data directory for persistence
N8N_DATA_DIR="$HOME/.n8n-mcp-test"
# API key storage file
API_KEY_FILE="$N8N_DATA_DIR/.n8n-api-key"

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to check if Docker is installed
check_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker is installed${NC}"
        # Check if Docker daemon is running
        if ! docker info &> /dev/null; then
            echo -e "${YELLOW}⚠️  Docker is installed but not running${NC}"
            echo -e "${YELLOW}Please start Docker and run this script again${NC}"
            exit 1
        fi
        return 0
    else
        echo -e "${RED}❌ Docker is not installed${NC}"
        echo "Please install Docker from https://docs.docker.com/get-docker/"
        exit 1
    fi
}

# Check if Docker Compose is installed
check_docker_compose() {
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✅ Docker Compose is installed${NC}"
        return 0
    else
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        echo "Please install Docker Compose"
        exit 1
    fi
}

# Check for Docker and Docker Compose
check_docker
check_docker_compose

# Check for jq (optional but recommended)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq is not installed (optional)${NC}"
    echo -e "${YELLOW}   Install it for pretty JSON output in tests${NC}"
fi

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    
    # Stop and remove containers
    cd "$PROJECT_DIR"
    docker compose down
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Create n8n data directory if it doesn't exist
if [ ! -d "$N8N_DATA_DIR" ]; then
    echo -e "${YELLOW}📁 Creating n8n data directory: $N8N_DATA_DIR${NC}"
    mkdir -p "$N8N_DATA_DIR"
fi

# Check for saved API key
if [ -f "$API_KEY_FILE" ]; then
    # Read saved API key
    N8N_API_KEY=$(cat "$API_KEY_FILE" 2>/dev/null || echo "")
    
    if [ -n "$N8N_API_KEY" ]; then
        echo -e "\n${GREEN}✅ Using saved n8n API key${NC}"
        echo -e "${YELLOW}   To use a different key, delete: ${API_KEY_FILE}${NC}"
        
        # Give user a chance to override
        echo -e "\n${YELLOW}Press Enter to continue with saved key, or paste a new API key:${NC}"
        read -r NEW_API_KEY
        
        if [ -n "$NEW_API_KEY" ]; then
            N8N_API_KEY="$NEW_API_KEY"
            # Save the new key
            echo "$N8N_API_KEY" > "$API_KEY_FILE"
            chmod 600 "$API_KEY_FILE"
            echo -e "${GREEN}✅ New API key saved${NC}"
        fi
    else
        # File exists but is empty, remove it
        rm -f "$API_KEY_FILE"
    fi
fi

# If no saved key, prompt for one
if [ -z "$N8N_API_KEY" ]; then
    # Guide user to get API key
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🔑 n8n API Key Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\nTo enable n8n management tools, you need to create an API key:"
    echo -e "\n${GREEN}Steps:${NC}"
    echo -e "  1. Open n8n in your browser: ${BLUE}http://localhost:${N8N_PORT}${NC}"
    echo -e "  2. Click on your user menu (top right)"
    echo -e "  3. Go to 'Settings'"
    echo -e "  4. Navigate to 'API'"
    echo -e "  5. Click 'Create API Key'"
    echo -e "  6. Give it a name (e.g., 'n8n-mcp')"
    echo -e "  7. Copy the generated API key"
    echo -e "\n${YELLOW}Note: If this is your first time, you'll need to create an account first.${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Wait for API key input
    echo -e "\n${YELLOW}Please paste your n8n API key here (or press Enter to skip):${NC}"
    read -r N8N_API_KEY
    
    # Save the API key if provided
    if [ -n "$N8N_API_KEY" ]; then
        echo "$N8N_API_KEY" > "$API_KEY_FILE"
        chmod 600 "$API_KEY_FILE"
        echo -e "${GREEN}✅ API key saved for future use${NC}"
    fi
fi

# Export environment variables for docker-compose
export N8N_API_KEY="${N8N_API_KEY:-}"

# Start services with Docker Compose
echo -e "\n${GREEN}🐳 Starting services with Docker Compose...${NC}"
cd "$PROJECT_DIR"
docker compose up -d

# Wait for n8n to be ready
echo -e "${YELLOW}⏳ Waiting for n8n to start...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:${N8N_PORT}/ >/dev/null 2>&1; then
        echo -e "${GREEN}✅ n8n is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ n8n failed to start${NC}"
        exit 1
    fi
    sleep 1
done

# Wait for MCP server to be ready
echo -e "${YELLOW}⏳ Waiting for MCP server to start...${NC}"
for i in {1..30}; do
    if docker logs n8n-mcp-server 2>&1 | grep -q "MCP Server running" || docker logs n8n-mcp-server 2>&1 | grep -q "Server started"; then
        echo -e "${GREEN}✅ MCP server is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ MCP server failed to start${NC}"
        echo "Check logs with: docker logs n8n-mcp-server"
        exit 1
    fi
    sleep 1
done

# Check if API key was provided
if [ -z "$N8N_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  No API key provided. n8n management tools will not be available.${NC}"
    echo -e "${YELLOW}   You can still use documentation and search tools.${NC}"
fi

# Show status
echo -e "\n${GREEN}🎉 Both services are running!${NC}"
echo -e "\n📍 Services:"
echo -e "  • n8n UI: ${BLUE}http://localhost:${N8N_PORT}${NC}"
echo -e "  • MCP server: Running in Docker container for Claude Code"
echo -e "\n💾 n8n data stored in: ${N8N_DATA_DIR}"
echo -e "   (Your workflows, credentials, and settings are preserved between runs)"

# Test available tools
echo -e "\n${YELLOW}🧪 Checking available MCP tools...${NC}"
if [ -n "$N8N_API_KEY" ]; then
    echo -e "${GREEN}✅ n8n Management Tools Available:${NC}"
    echo "   • n8n_list_workflows - List all workflows"
    echo "   • n8n_get_workflow - Get workflow details"
    echo "   • n8n_create_workflow - Create new workflows"
    echo "   • n8n_update_workflow - Update existing workflows"
    echo "   • n8n_delete_workflow - Delete workflows"
    echo "   • n8n_trigger_webhook_workflow - Trigger webhook workflows"
    echo "   • n8n_list_executions - List workflow executions"
    echo "   • And more..."
else
    echo -e "${YELLOW}⚠️  n8n Management Tools NOT Available${NC}"
    echo "   To enable, restart with an n8n API key"
fi

echo -e "\n${GREEN}✅ Documentation Tools Always Available:${NC}"
echo "   • list_nodes - List available n8n nodes"
echo "   • search_nodes - Search for specific nodes"
echo "   • get_node_info - Get detailed node information"
echo "   • validate_node_operation - Validate node configurations"
echo "   • And many more..."

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📝 Claude Code Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${GREEN}✅ MCP configuration already set up!${NC}"
echo -e "\nThis project includes ${BLUE}.mcp.json${NC} which configures the n8n-mcp server"
echo -e "for Claude Code automatically."
echo -e "\n${YELLOW}To use n8n-mcp in Claude Code:${NC}"
echo -e "  1. Open this project in Claude Code"
echo -e "  2. The MCP server will be available automatically"
echo -e "  3. You can use commands like 'list available n8n nodes' or 'search for HTTP nodes'"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\n${GREEN}✅ Setup complete!${NC}"
echo -e "\n📝 You can now:"
echo -e "  1. Use Claude Code to interact with n8n documentation and tools"
echo -e "  2. Open n8n at ${BLUE}http://localhost:${N8N_PORT}${NC} to test workflows"
echo -e "\n${YELLOW}Press Ctrl+C to stop both services${NC}"
echo -e "\n${YELLOW}📋 To monitor logs:${NC}"
echo -e "  • All services: docker compose logs -f"
echo -e "  • n8n only: docker compose logs -f n8n"
echo -e "  • MCP server only: docker compose logs -f n8n-mcp"

# Keep script running
echo -e "\n${YELLOW}Services are running. Press Ctrl+C to stop.${NC}"
while true; do
    sleep 1
done