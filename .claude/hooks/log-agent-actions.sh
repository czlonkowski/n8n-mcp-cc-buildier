#!/bin/bash

# Log agent and sub-agent actions to a structured log file
LOG_DIR="$CLAUDE_PROJECT_DIR/logs/agent-actions"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d)-agent-actions.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Read the hook input JSON
INPUT=$(cat)

# Extract relevant fields
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
EVENT_TYPE="${CLAUDE_HOOK_EVENT}"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')

# For Task tool (agent invocations), extract agent details
if [ "$TOOL_NAME" = "Task" ]; then
    SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "unknown"')
    TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // "unknown"')
    PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' | tr '\n' ' ' | cut -c1-200)
    
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
    TOOL_INPUT_PREVIEW=$(echo "$INPUT" | jq -r '.tool_input // {}' | jq -c . | cut -c1-200)
    
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

# Append to log file
echo "$LOG_ENTRY" >> "$LOG_FILE"

# For PostToolUse events, also log the response
if [ "$EVENT_TYPE" = "PostToolUse" ]; then
    TOOL_RESPONSE_PREVIEW=$(echo "$INPUT" | jq -r '.tool_response // ""' | cut -c1-500)
    
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
    
    echo "$RESPONSE_LOG" >> "$LOG_FILE"
fi

# Exit successfully
exit 0