#!/bin/bash

# Enhanced script to view agent action logs

LOG_DIR="$1"
if [ -z "$LOG_DIR" ]; then
    LOG_DIR="./logs/agent-actions"
fi

# Get the most recent log file if no specific file is provided
if [ -z "$2" ]; then
    LOG_FILE=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | grep -v debug | head -1)
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
    if [ -z "$line" ] || ! echo "$line" | jq -e . >/dev/null 2>&1; then
        continue
    fi
    
    # Parse JSON fields
    timestamp=$(echo "$line" | jq -r '.timestamp // ""')
    event=$(echo "$line" | jq -r '.event // ""')
    tool=$(echo "$line" | jq -r '.tool // ""')
    
    # Skip empty events (these seem to be from hooks not setting event type)
    if [ -z "$event" ] || [ "$event" = "" ]; then
        event="ToolUse"
    fi
    
    # Format based on tool and event type
    case "$tool" in
        "Task")
            agent=$(echo "$line" | jq -r '.agent_type // ""')
            desc=$(echo "$line" | jq -r '.task_description // ""')
            echo "[$timestamp] 🚀 AGENT INVOKED: $agent"
            echo "   Task: $desc"
            prompt=$(echo "$line" | jq -r '.prompt_preview // ""' | sed 's/\.\.\.$//')
            if [ -n "$prompt" ] && [ "$prompt" != "" ]; then
                echo "   Request: ${prompt:0:100}..."
            fi
            echo
            ;;
        *)
            case "$event" in
                "PreToolUse"|"ToolUse")
                    echo "[$timestamp] 🔧 Tool Use: $tool"
                    input=$(echo "$line" | jq -r '.input_preview // ""' | sed 's/\.\.\.$//')
                    if [ -n "$input" ] && [ "$input" != "{}" ]; then
                        echo "   Input: ${input:0:100}..."
                    fi
                    ;;
                "PostToolUse")
                    echo "[$timestamp] ✅ Tool Complete: $tool"
                    ;;
                "ToolResponse")
                    response=$(echo "$line" | jq -r '.response_preview // ""' | sed 's/\.\.\.$//')
                    echo "   Response: ${response:0:150}..."
                    echo
                    ;;
                "SubagentStop")
                    echo "[$timestamp] 🛑 Subagent Stopped"
                    echo
                    ;;
                *)
                    echo "[$timestamp] 📌 Event: $event - Tool: $tool"
                    ;;
            esac
            ;;
    esac
done < "$LOG_FILE"

# Summary statistics
echo
echo "=== Summary ==="
total_lines=$(wc -l < "$LOG_FILE")
agent_invocations=$(grep -c '"tool":"Task"' "$LOG_FILE" 2>/dev/null || echo 0)
total_tools=$(grep -c '"tool":' "$LOG_FILE" 2>/dev/null || echo 0)

echo "Total log entries: $total_lines"
echo "Agent invocations: $agent_invocations"
echo "Total tool uses: $total_tools"

# Show agents used
if [ $agent_invocations -gt 0 ]; then
    echo
    echo "Agents invoked:"
    grep '"tool":"Task"' "$LOG_FILE" | jq -r '.agent_type' | sort | uniq -c | while read count agent; do
        echo "   $count x $agent"
    done
fi

# Check for debug log
DEBUG_LOG="$LOG_DIR/debug-$(date +%Y-%m-%d).log"
if [ -f "$DEBUG_LOG" ]; then
    echo
    echo "Debug log available: $DEBUG_LOG"
fi