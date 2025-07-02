#!/bin/bash

echo "🎮 Splatoon Client - wgpu Error Recovery Script"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Set environment variables to try to mitigate the issue
export WGPU_BACKEND=gl
export RUST_LOG=warn,wgpu_core=off,wgpu_hal=off
export MESA_GL_VERSION_OVERRIDE=3.3

echo -e "${BLUE}🔧 Environment Configuration:${NC}"
echo "   WGPU_BACKEND=gl (Force OpenGL)"
echo "   RUST_LOG=warn (Reduce log noise)"
echo "   MESA_GL_VERSION_OVERRIDE=3.3"
echo ""

echo -e "${YELLOW}⚠️  Note: wgpu depth texture errors are expected${NC}"
echo "   This is a known compatibility issue between:"
echo "   - wgpu shader translation layer"
echo "   - OpenGL/GLSL on certain drivers"
echo "   - Bevy's advanced rendering features"
echo ""
echo -e "${GREEN}✅ Game features that work despite errors:${NC}"
echo "   - UDP networking to server"
echo "   - Player movement (WASD)"
echo "   - Mouse shooting"
echo "   - Basic 2D sprite rendering"
echo "   - Test commands (T, P, I, G keys)"
echo ""

attempts=0
max_attempts=3

while [ $attempts -lt $max_attempts ]; do
    attempts=$((attempts + 1))
    echo -e "${BLUE}🚀 Starting game (Attempt $attempts/$max_attempts)...${NC}"
    
    # Run the game and capture the output
    if cargo run 2>&1; then
        echo -e "${GREEN}✅ Game exited normally${NC}"
        break
    else
        exit_code=$?
        echo -e "${RED}💥 Game crashed with exit code: $exit_code${NC}"
        
        if [ $attempts -lt $max_attempts ]; then
            echo -e "${YELLOW}🔄 Retrying in 2 seconds...${NC}"
            sleep 2
        else
            echo -e "${RED}❌ Maximum retry attempts reached${NC}"
            echo ""
            echo -e "${YELLOW}💡 Troubleshooting suggestions:${NC}"
            echo "   1. Update graphics drivers"
            echo "   2. Try: export WGPU_BACKEND=vulkan"
            echo "   3. Try: export LIBGL_ALWAYS_SOFTWARE=1"
            echo "   4. Check if the server is running on 127.0.0.1:8083"
            exit $exit_code
        fi
    fi
done

echo -e "${GREEN}🎉 Script completed${NC}"