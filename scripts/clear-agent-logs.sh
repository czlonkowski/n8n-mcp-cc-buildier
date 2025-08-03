#!/bin/bash

# Clear agent logs script
# This script removes all log files from the logs/agent-actions directory

LOGS_DIR="logs/agent-actions"

# Check if logs directory exists
if [ -d "$LOGS_DIR" ]; then
    echo "Clearing agent logs in $LOGS_DIR..."
    
    # Count files before deletion
    FILE_COUNT=$(find "$LOGS_DIR" -type f -name "*.log" 2>/dev/null | wc -l)
    
    if [ "$FILE_COUNT" -gt 0 ]; then
        # Remove all .log files
        find "$LOGS_DIR" -type f -name "*.log" -delete
        echo "✓ Removed $FILE_COUNT log file(s)"
    else
        echo "No log files found to clear"
    fi
else
    echo "Logs directory $LOGS_DIR does not exist"
fi