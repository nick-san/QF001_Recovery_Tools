#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
ARCH="$(uname -m)"
SPD_BIN="$REPO_ROOT/spd_dump_${ARCH}"
SRC_DIR="$REPO_ROOT/spreadtrum_flash"

if [ ! -f "$SRC_DIR/spd_dump.c" ]; then
    echo ">> Submodule not found. Initializing..."
    (cd "$REPO_ROOT" && git submodule update --init --recursive)
fi

echo ">> Compiling spd_dump for $ARCH from submodule..."
BUILD_SUCCESS=0

LIBUSB_CFLAGS="$(pkg-config --cflags libusb-1.0 2>/dev/null || true)"
LIBUSB_LIBS="$(pkg-config --libs libusb-1.0 2>/dev/null || echo '-lusb-1.0')"

# 1. pkg-config または標準リンクでビルド
if gcc -O2 $LIBUSB_CFLAGS -I"$SRC_DIR" -DUSE_LIBUSB=1 "$SRC_DIR/spd_dump.c" $LIBUSB_LIBS -o "$SPD_BIN" 2>/dev/null; then
    BUILD_SUCCESS=1
# 2. 直リンクフォールバック (.so.0)
elif gcc -O2 $LIBUSB_CFLAGS -I"$SRC_DIR" -DUSE_LIBUSB=1 "$SRC_DIR/spd_dump.c" -l:libusb-1.0.so.0 -o "$SPD_BIN" 2>/dev/null; then
    BUILD_SUCCESS=1
fi

if [ $BUILD_SUCCESS -eq 1 ]; then
    chmod +x "$SPD_BIN"
    ln -sf "$SPD_BIN" "$REPO_ROOT/spd_dump_usb"
    echo ">> コンパイル成功: $SPD_BIN"
    echo ">> シンボリックリンク更新: $REPO_ROOT/spd_dump_usb"
else
    echo ""
    echo "[エラー] コンパイルに失敗しました。libusb 開発パッケージがインストールされているか確認してください。"
    echo "  - Ubuntu / Debian / Mint: sudo apt update && sudo apt install -y build-essential libusb-1.0-0-dev"
    echo "  - Fedora / RHEL:          sudo dnf install -y gcc libusb1-devel"
    echo "  - Arch Linux:             sudo pacman -S gcc libusb"
    echo ""
    exit 1
fi
