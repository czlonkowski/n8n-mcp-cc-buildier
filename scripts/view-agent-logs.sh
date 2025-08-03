#!/bin/bash

# Script to view agent action logs in a readable format

LOG_DIR="$1"
if [ -z "$LOG_DIR" ]; then
    LOG_DIR="./logs/agent-actions"
fi

# Get the most recent log file if no specific file is provided
if [ -z "$2" ]; then
    LOG_FILE=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
else
    LOG_FILE="$2"
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "No log file found. Usage: $0 [log_directory] [log_file]"
    exit 1
fi

echo "=== Agent Action Log: $(basename "$LOG_FILE") ==="
echo

# Process the log file and format output
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    # Parse JSON fields
    timestamp=$(echo "$line" | jq -r '.timestamp // ""')
    event=$(echo "$line" | jq -r '.event // ""')
    tool=$(echo "$line" | jq -r '.tool // ""')
    
    # Format based on event type
    case "$event" in
        "PreToolUse")
            if [ "$tool" = "Task" ]; then
                agent=$(echo "$line" | jq -r '.agent_type // ""')
                desc=$(echo "$line" | jq -r '.task_description // ""')
                echo "[$timestamp] 🚀 AGENT INVOKED: $agent"
                echo "   Task: $desc"
                echo
            else
                echo "[$timestamp] 🔧 Tool Use: $tool"
            fi
            ;;
        "PostToolUse")
            echo "[$timestamp] ✅ Tool Complete: $tool"
            ;;
        "ToolResponse")
            response=$(echo "$line" | jq -r '.response_preview // ""')
            echo "   Response: $response"
            echo
            ;;
        "SubagentStop")
            echo "[$timestamp] 🛑 Subagent Stopped"
            echo
            ;;
    esac
done < "$LOG_FILE"

# Summary statistics
echo
echo "=== Summary ==="
echo "Total events: $(wc -l < "$LOG_FILE")"
echo "Agent invocations: $(grep -c '"tool":"Task"' "$LOG_FILE" || echo 0)"
echo "Tool uses: $(grep -c '"event":"PreToolUse"' "$LOG_FILE" || echo 0)"