#!/bin/bash

# Function to safely remove files and directories
remove_if_exists() {
    if [ -e "$1" ]; then
        rm -rf "$1"
        echo "✓ Removed: $1"
    fi
}

# Clean Zig build outputs and WASM files
echo "🧹 Cleaning Zig build outputs and WASM files..."

remove_if_exists ".zig-cache"
remove_if_exists "zig-out"
remove_if_exists "color_palette_contract.wasm.o"
remove_if_exists "color_palette_contract.wasm"

echo "✨ Cleanup complete!"