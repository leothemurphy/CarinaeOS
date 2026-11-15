#!/bin/sh
# Builds Carinae 3D on Linux. Run once from this folder: ./build-linux.sh
set -e

if [ ! -f Cargo.toml ]; then
    echo "Run this from the folder that holds Cargo.toml." >&2
    exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "Cargo is not installed. Get it from https://rustup.rs (or your package manager)." >&2
    exit 1
fi

# .cargo/config.toml pins the Windows linker (MinGW) so the Windows build works;
# on Linux it would be the wrong linker, so it steps aside for this build.
restore_cfg=""
if [ -f .cargo/config.toml ]; then
    mv .cargo/config.toml .cargo/config.toml.windows
    restore_cfg="yes"
    echo "Set .cargo/config.toml aside (it pins a Windows linker); it comes back at the end."
fi
trap 'if [ -n "$restore_cfg" ]; then mv .cargo/config.toml.windows .cargo/config.toml; fi' EXIT

# eframe talks to the desktop through these; pkg-config has to find them.
missing=""
for pkg in xkbcommon wayland-client x11 xcursor xrandr xi gl; do
    if ! pkg-config --exists "$pkg" 2>/dev/null; then
        missing="$missing $pkg"
    fi
done
if [ -n "$missing" ]; then
    echo "Missing development packages:$missing" >&2
    echo "On Debian/Ubuntu:" >&2
    echo "  sudo apt install build-essential pkg-config libxkbcommon-dev libwayland-dev \\" >&2
    echo "                   libx11-dev libxcursor-dev libxrandr-dev libxi-dev libgl1-mesa-dev" >&2
    echo "On Fedora:" >&2
    echo "  sudo dnf install gcc pkgconf libxkbcommon-devel wayland-devel libX11-devel \\" >&2
    echo "                   libXcursor-devel libXrandr-devel libXi-devel mesa-libGL-devel" >&2
    exit 1
fi

cargo build --release
echo
echo "Built: target/release/carinae-3d"
