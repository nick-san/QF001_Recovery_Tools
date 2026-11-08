#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
ARCH="$(uname -m)"
SPD_BIN="$REPO_ROOT/spd_dump_${ARCH}"
FDL1="$REPO_ROOT/fdl/fdl1-dl.bin"
FDL2="$REPO_ROOT/fdl/fdl2-dl.bin"

BOOT_IMG="${1:-$REPO_ROOT/stock_boot.img}"
VBMETA_IMG="${2:-$REPO_ROOT/stock_vbmeta.img}"

echo "=================================================="
echo "  Unisoc UIS7862 BootROM Recovery Flasher         "
echo "  Target Architecture: $ARCH                      "
echo "=================================================="

if [ ! -f "$BOOT_IMG" ] || [ ! -f "$VBMETA_IMG" ]; then
    echo ""
    echo "[エラー] 復元用の boot または vbmeta イメージが見つかりません。"
    echo "  - boot:   $BOOT_IMG"
    echo "  - vbmeta: $VBMETA_IMG"
    echo ""
    echo "使用方法:"
    echo "  $0 <boot.img のパス> <vbmeta.img のパス>"
    echo "または、本リポジトリ直下に stock_boot.img および stock_vbmeta.img を配置してください。"
    exit 1
fi

# アーキテクチャ専用バイナリの存在確認 & 自動コンパイル
if [ ! -f "$SPD_BIN" ] || [ "$REPO_ROOT/spreadtrum_flash/spd_dump.c" -nt "$SPD_BIN" ]; then
    bash "$DIR/build.sh"
fi

echo ""
echo "書き戻し対象:"
echo "  - vbmeta:     $VBMETA_IMG"
echo "  - vbmeta_bak: $VBMETA_IMG"
echo "  - boot:       $BOOT_IMG"
echo "=================================================="
echo ">> 手順:"
echo " 1. 10ピン端子の10番ピンをアンテナ外周(GND)に接触させてキープ"
echo " 2. ナビの電源(12V/ACC)を ON (または RST ピンを押す)"
echo " 3. 'BSL_REP_VER: \"SPRD3\\0\"' が表示された瞬間に、10番ピンを必ず離す"
echo "    FDL1/FDL2 の転送や書き込み開始まで保持しないでください"
echo "=================================================="
echo "接続待機中 (最大300秒)..."

# root権限の確認
if [ "$EUID" -ne 0 ]; then
    echo "※注意: USB直接アクセスのため sudo が必要な場合があります。"
fi

"$SPD_BIN" --wait 300 \
    fdl "$FDL1" 0x5500 \
    fdl "$FDL2" 0x9efffe00 \
    disable_transcode \
    timeout 15000 \
    blk_size 0x1000 \
    write_part vbmeta "$VBMETA_IMG" \
    write_part vbmeta_bak "$VBMETA_IMG" \
    write_part boot "$BOOT_IMG" \
    reset

echo ""
echo "=================================================="
echo "  [SUCCESS] 全復元が完了しました！"
echo "  ナビが再起動し、Androidが起動するか確認してください。"
echo "=================================================="
