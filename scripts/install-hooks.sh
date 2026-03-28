#!/bin/bash
# Install git hooks for AfterClose development
# Run once after cloning: ./scripts/install-hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(git rev-parse --show-toplevel)/.git/hooks"

cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Git hooks installed successfully"
