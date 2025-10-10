#!/bin/bash

# Enhanced build script for Godot-Vodozemac (vodozemac GDExtension)
# This script mimics the caching behavior from .github/workflows/build_release.yml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Configuration ---
PLATFORM=""
ARCH="x86_64"
SCONS_FLAGS=""

# --- Helper Functions ---
show_usage() {
    echo -e "${YELLOW}Usage: $0 [linux|macos|windows]${NC}"
    echo "  linux: Build for Linux (x86_64)"
    echo "  macos: Build for macOS (universal)"
    echo "  windows: Build for Windows (x86_64, cross-compile)"
    exit 1
}

# --- Platform-specific Setup ---
setup_linux() {
    PLATFORM="linux"
    ARCH="x86_64"
    SCONS_FLAGS="platform=linux"
    echo -e "${BLUE}=== Godot-Vodozemac Local Build Script (Linux) ===${NC}"
}

setup_macos() {
    PLATFORM="macos"
    ARCH="universal"
    SCONS_FLAGS="platform=macos arch=universal"
    echo -e "${BLUE}=== Godot-Vodozemac Local Build Script (macOS) ===${NC}"
}

setup_windows() {
    PLATFORM="windows"
    ARCH="x86_64"
    SCONS_FLAGS="platform=windows use_mingw=yes"
    echo -e "${BLUE}=== Godot-Vodozemac Local Build Script (Windows Cross-Compile) ===${NC}"
}

# --- Build Functions ---

# Function to check if godot-cpp cache is valid
check_godotcpp_cache() {
    echo -e "${YELLOW}Checking godot-cpp cache...${NC}"
    
    # When cross-compiling with MinGW, we still get .a files, not .lib files
    # .lib files are only produced when building with MSVC on Windows
    local lib_ext="a"

    local required_files=(
        "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_release.${ARCH}.${lib_ext}"
        "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_debug.${ARCH}.${lib_ext}"
        "godot-cpp/gen/include"
        "godot-cpp/gen/src"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            echo -e "${RED}Cache miss: $file not found${NC}"
            return 1
        fi
    done
    
    if [ -f "godot-cpp/.sconsign.dblite" ]; then
        echo -e "${GREEN}SCons signature file found${NC}"
    fi
    
    echo -e "${GREEN}godot-cpp cache is valid!${NC}"
    return 0
}

# Function to build vodozemac-ffi
build_vodozemac_ffi() {
    echo -e "${YELLOW}Building vodozemac-ffi for ${PLATFORM}...${NC}"

    cd vodozemac-ffi/cpp

    local cargo_flags="--release"
    if [ "$PLATFORM" == "windows" ]; then
        cargo_flags="$cargo_flags --target=x86_64-pc-windows-gnu"
    elif [ "$PLATFORM" == "macos" ] && [ "$ARCH" == "universal" ]; then
        # Build for both x86_64 and arm64 and combine them with lipo
        cargo build --release --target=x86_64-apple-darwin
        cargo build --release --target=aarch64-apple-darwin

        mkdir -p ../target/universal-apple-darwin/release
        lipo -create \
            ../target/x86_64-apple-darwin/release/libvodozemac.a \
            ../target/aarch64-apple-darwin/release/libvodozemac.a \
            -output ../target/universal-apple-darwin/release/libvodozemac.a

        # Copy the universal library to the expected location
        mkdir -p ../target/release
        cp ../target/universal-apple-darwin/release/libvodozemac.a ../target/release/libvodozemac.a

        cd ../..
        echo -e "${GREEN}vodozemac-ffi build completed successfully!${NC}"
        return
    fi

    cargo build $cargo_flags

    cd ../..
    echo -e "${GREEN}vodozemac-ffi build completed successfully!${NC}"
}

# Function to check if vodozemac-ffi cache is valid
check_vodozemac_ffi_cache() {
    echo -e "${YELLOW}Checking vodozemac-ffi cache...${NC}"

    local lib_path="vodozemac-ffi/target/release/libvodozemac.a"
    if [ "$PLATFORM" == "windows" ]; then
        lib_path="vodozemac-ffi/target/x86_64-pc-windows-gnu/release/libvodozemac.a"
    fi

    if [ ! -f "$lib_path" ]; then
        echo -e "${RED}Cache miss: $lib_path not found${NC}"
        return 1
    fi

    echo -e "${GREEN}vodozemac-ffi cache is valid!${NC}"
    return 0
}


# Function to build godot-cpp
build_godotcpp() {
    echo -e "${YELLOW}Building godot-cpp (cache miss)...${NC}"
    
    cd godot-cpp
    
    echo -e "${BLUE}Building template_release...${NC}"
    scons $SCONS_FLAGS generate_bindings=yes target=template_release
    
    echo -e "${BLUE}Building template_debug...${NC}"
    scons $SCONS_FLAGS generate_bindings=yes target=template_debug
    
    cd ..
    
    echo -e "${GREEN}godot-cpp build completed!${NC}"
}

# Function to install dependencies
install_dependencies() {
    echo -e "${YELLOW}Checking dependencies for ${PLATFORM}...${NC}"
    
    local required_tools=("scons" "g++")
    if [ "$PLATFORM" == "linux" ]; then
        if [[ "$OSTYPE" != "linux-gnu"* ]]; then
            echo -e "${RED}Linux build requires a Linux environment. Current OS: $OSTYPE${NC}"
            exit 1
        fi
    elif [ "$PLATFORM" == "windows" ]; then
        required_tools+=("x86_64-w64-mingw32-gcc" "x86_64-w64-mingw32-g++")
    elif [ "$PLATFORM" == "macos" ]; then
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo -e "${RED}macOS build requires a macOS environment. Current OS: $OSTYPE${NC}"
            exit 1
        fi
    fi

    # Check for Rust/Cargo
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}Rust toolchain (cargo) not found!${NC}"
        echo -e "${YELLOW}Please install Rust: https://www.rust-lang.org/tools/install${NC}"
        exit 1
    fi
    echo -e "${GREEN}Rust toolchain found${NC}"


    local missing_tools=()
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install them for your system.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All required dependencies are available${NC}"
}

# Function to build the main project
build_main_project() {
    echo -e "${YELLOW}Building main project...${NC}"
    scons $SCONS_FLAGS target=template_release
    echo -e "${GREEN}Main project build completed!${NC}"
}

# Function to package addon
package_addon() {
    echo -e "${YELLOW}Packaging addon...${NC}"
    
    local artifact_name="godot-vodozemac-${PLATFORM}-${ARCH}"
    
    mkdir -p "package/addons"
    cp -r "addons/godot-vodozemac" "package/addons/"
    
    # Correctly copy the library based on the platform
    if [ "$PLATFORM" == "macos" ]; then
        cp "addons/godot-vodozemac/bin/libgodot-vodozemac.dylib" "package/addons/godot-vodozemac/bin/" 2>/dev/null || \
        echo -e "${YELLOW}Warning: macOS library not found${NC}"
    elif [ "$PLATFORM" == "windows" ]; then
        cp "addons/godot-vodozemac/bin/libgodot-vodozemac.dll" "package/addons/godot-vodozemac/bin/" 2>/dev/null || \
        echo -e "${YELLOW}Warning: Windows library not found${NC}"
    elif [ "$PLATFORM" == "linux" ]; then
        cp "addons/godot-vodozemac/bin/libgodot-vodozemac.so" "package/addons/godot-vodozemac/bin/" 2>/dev/null || \
        echo -e "${YELLOW}Warning: Linux library not found${NC}"
    else
        echo -e "${YELLOW}Packaging for ${PLATFORM} is not fully implemented yet.${NC}"
    fi

    cd "package"
    zip -r "../${artifact_name}.zip" .
    cd ..
    
    rm -rf "package"
    
    echo -e "${GREEN}Addon packaged as ${artifact_name}.zip${NC}"
}

# Function to show cache status
show_cache_status() {
    echo -e "${BLUE}=== Cache Status ===${NC}"
    
    # Check vodozemac-ffi cache
    if check_vodozemac_ffi_cache; then
        echo -e "${GREEN}✓ vodozemac-ffi library cached${NC}"
    else
        echo -e "${RED}✗ vodozemac-ffi library missing${NC}"
    fi
    
    # When cross-compiling with MinGW, we still get .a files, not .lib files
    # .lib files are only produced when building with MSVC on Windows
    local lib_ext="a"

    if [ -f "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_release.${ARCH}.${lib_ext}" ]; then
        echo -e "${GREEN}✓ Release library cached${NC}"
    else
        echo -e "${RED}✗ Release library missing${NC}"
    fi
    
    if [ -f "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_debug.${ARCH}.${lib_ext}" ]; then
        echo -e "${GREEN}✓ Debug library cached${NC}"
    else
        echo -e "${RED}✗ Debug library missing${NC}"
    fi
    
    if [ -d "godot-cpp/gen/include" ] && [ -d "godot-cpp/gen/src" ]; then
        echo -e "${GREEN}✓ Generated bindings cached${NC}"
    else
        echo -e "${RED}✗ Generated bindings missing${NC}"
    fi
    
    if [ -f "godot-cpp/.sconsign.dblite" ]; then
        echo -e "${GREEN}✓ SCons signature file present${NC}"
    else
        echo -e "${YELLOW}! SCons signature file missing (will be created)${NC}"
    fi
    
    echo ""
}

# --- Main Execution ---
main() {
    # Parse command-line arguments
    if [ -z "$1" ]; then
        show_usage
    fi

    case "$1" in
        linux)
            setup_linux
            ;;
        macos)
            setup_macos
            ;;
        windows)
            export CC=x86_64-w64-mingw32-gcc
            export CXX=x86_64-w64-mingw32-g++
            setup_windows
            ;;
        *)
            show_usage
            ;;
    esac

    echo -e "${BLUE}Platform: ${PLATFORM}, Architecture: ${ARCH}${NC}"
    echo ""

    install_dependencies
    show_cache_status
    
    if ! check_vodozemac_ffi_cache; then
        build_vodozemac_ffi
    else
        echo -e "${GREEN}Using cached vodozemac-ffi build${NC}"
    fi
    
    if ! check_godotcpp_cache; then
        build_godotcpp
    else
        echo -e "${GREEN}Using cached godot-cpp build${NC}"
    fi
    
    echo ""
    build_main_project
    echo ""
    
    read -p "Do you want to package the addon? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        package_addon
    fi
    
    echo ""
    echo -e "${GREEN}=== Build Complete! ===${NC}"
    echo -e "${BLUE}Built for: ${PLATFORM} (${ARCH})${NC}"
    
    show_cache_status
}

main "$@"