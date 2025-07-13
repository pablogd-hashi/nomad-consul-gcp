#!/bin/bash

# Clean up Claude references from commit messages
# Remove the Claude Code attribution and Co-Authored-By lines

if [[ "$GIT_COMMIT" ]]; then
    # Remove Claude-specific lines from commit message
    echo "$1" | sed '/🤖 Generated with \[Claude Code\]/d' | sed '/Co-Authored-By: Claude/d' | sed '/^\s*$/d'
else
    echo "$1"
fi