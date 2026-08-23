#!/usr/bin/env bash
set -e

# ViewLens — 100% Pure Swift MCP Server & CLI Installer Script

echo "============================================================"
echo "🔍 ViewLens Pure Swift MCP Server & CLI Setup"
echo "============================================================"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "1. Building release binary (viewlens)..."
swift build -c release --product viewlens

BIN_PATH="$REPO_ROOT/.build/release/viewlens"
echo "✅ Built native binary at: $BIN_PATH"

echo ""
echo "2. Running ViewLens diagnostics..."
"$BIN_PATH" doctor || true

echo ""
echo "============================================================"
echo "🎉 Setup Complete! Zero Python Dependencies Needed."
echo "============================================================"
echo ""
echo "To configure Claude Code (~/.claude/settings.json):"
echo ""
cat << EOF
{
  "mcpServers": {
    "viewlens": {
      "command": "$BIN_PATH",
      "args": ["mcp"]
    }
  }
}
EOF
echo ""
echo "To configure Cursor (.cursor/mcp.json):"
echo ""
cat << EOF
{
  "mcpServers": {
    "viewlens": {
      "command": "$BIN_PATH",
      "args": ["mcp"]
    }
  }
}
EOF
echo ""
