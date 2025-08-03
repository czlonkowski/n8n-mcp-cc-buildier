#!/bin/bash

# Enhanced logging for agent and sub-agent actions
LOG_DIR="$CLAUDE_PROJECT_DIR/logs/agent-actions"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d)-agent-actions.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Read the hook input JSON
INPUT=$(cat)

# Debug: Log raw input to understand what we're getting
DEBUG_FILE="$LOG_DIR/debug-$(date +%Y-%m-%d).log"
echo "=== $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ") ===" >> "$DEBUG_FILE"
echo "CLAUDE_HOOK_EVENT: ${CLAUDE_HOOK_EVENT:-'NOT SET'}" >> "$DEBUG_FILE"
echo "INPUT:" >> "$DEBUG_FILE"
echo "$INPUT" | jq . >> "$DEBUG_FILE" 2>&1
echo "" >> "$DEBUG_FILE"

# Extract relevant fields with better defaults
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Try to determine event type from multiple sources
if [ -n "$CLAUDE_HOOK_EVENT" ]; then
    EVENT_TYPE="$CLAUDE_HOOK_EVENT"
elif echo "$INPUT" | jq -e '.event' >/dev/null 2>&1; then
    EVENT_TYPE=$(echo "$INPUT" | jq -r '.event')
else
    # Infer from hook configuration context
    EVENT_TYPE="Unknown"
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")

# For Task tool (agent invocations), extract agent details
if [ "$TOOL_NAME" = "Task" ]; then
    SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "unknown"' 2>/dev/null || echo "unknown")
    TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // "unknown"' 2>/dev/null || echo "unknown")
    PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr '\n' ' ' | cut -c1-200)
    
    # Log entry for agent invocation
    LOG_ENTRY=$(jq -n \
        --arg timestamp "$TIMESTAMP" \
        --arg event "$EVENT_TYPE" \
        --arg session "$SESSION_ID" \
        --arg tool "$TOOL_NAME" \
        --arg agent "$SUBAGENT_TYPE" \
        --arg desc "$TASK_DESCRIPTION" \
        --arg prompt "$PROMPT..." \
        '{
            timestamp: $timestamp,
            event: $event,
            session_id: $session,
            tool: $tool,
            agent_type: $agent,
            task_description: $desc,
            prompt_preview: $prompt
        }')
else
    # Log entry for other tools
    TOOL_INPUT_PREVIEW=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null | jq -c . 2>/dev/null | cut -c1-200)
    
    LOG_ENTRY=$(jq -n \
        --arg timestamp "$TIMESTAMP" \
        --arg event "$EVENT_TYPE" \
        --arg session "$SESSION_ID" \
        --arg tool "$TOOL_NAME" \
        --arg input "$TOOL_INPUT_PREVIEW..." \
        '{
            timestamp: $timestamp,
            event: $event,
            session_id: $session,
            tool: $tool,
            input_preview: $input
        }')
fi

# Ensure we write valid JSON on a single line
echo "$LOG_ENTRY" | jq -c . >> "$LOG_FILE"

# For PostToolUse events, also log the response
if [ "$EVENT_TYPE" = "PostToolUse" ]; then
    TOOL_RESPONSE_PREVIEW=$(echo "$INPUT" | jq -r '.tool_response // ""' 2>/dev/null | cut -c1-500)
    
    if [ -n "$TOOL_RESPONSE_PREVIEW" ]; then
        RESPONSE_LOG=$(jq -n \
            --arg timestamp "$TIMESTAMP" \
            --arg session "$SESSION_ID" \
            --arg tool "$TOOL_NAME" \
            --arg response "$TOOL_RESPONSE_PREVIEW..." \
            '{
                timestamp: $timestamp,
                event: "ToolResponse",
                session_id: $session,
                tool: $tool,
                response_preview: $response
            }')
        
        echo "$RESPONSE_LOG" | jq -c . >> "$LOG_FILE"
    fi
fi

# Exit successfully
exit 0