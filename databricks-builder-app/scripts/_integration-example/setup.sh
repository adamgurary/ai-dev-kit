#!/bin/bash
# One-command setup for AI Dev Kit integration example
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AI Dev Kit Integration Setup ==="
echo ""

# Check for uv or pip
if command -v uv &> /dev/null; then
    PKG_MANAGER="uv"
    echo "Using uv package manager"
else
    PKG_MANAGER="pip"
    echo "Using pip (consider installing uv for faster installs)"
fi

# Create virtual environment
echo ""
echo "Creating virtual environment..."
if [ "$PKG_MANAGER" = "uv" ]; then
    uv venv .venv
else
    python3 -m venv .venv
fi

# Activate venv
source .venv/bin/activate

# Install dependencies
echo ""
echo "Installing dependencies..."
if [ "$PKG_MANAGER" = "uv" ]; then
    uv pip install -r requirements.txt
else
    pip install -r requirements.txt
fi

# Install skills
echo ""
echo "Setting up skills directory..."
SKILLS_DIR="$SCRIPT_DIR/.claude/skills"
mkdir -p "$SKILLS_DIR"

# The in-repo bundled skills snapshot that this example used to copy from has
# been removed from the repo (the historical copies still exist on the older
# release v0.1.14). Install skills into "$SKILLS_DIR" via `databricks aitools
# install` or install_skills.sh from the v0.1.14 release.
echo "  Skills are no longer bundled in this repo — install them into"
echo "  $SKILLS_DIR (e.g. via 'databricks aitools install')."

# Copy .env.example to .env if it doesn't exist
if [ ! -f ".env" ]; then
    echo ""
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "Created .env - please edit with your credentials"
fi

# Create projects directory for agent working files
mkdir -p projects

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit .env with your Databricks and Claude credentials"
echo "  2. Activate the environment: source .venv/bin/activate"
echo "  3. Run the example: python example_integration.py"
echo ""
