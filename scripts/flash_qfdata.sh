#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
SPD_BIN="$REPO_ROOT/spd_dump_usb"
FDL1="$REPO_ROOT/fdl/fdl1-dl.bin"
FDL2="$REPO_ROOT/fdl/fdl2-dl.bin"
QFDATA_IMG="${1:-$REPO_ROOT/qfdata}"

if [ ! -f "$QFDATA_IMG" ]; then
    echo "[エラー] qfdata ファイルが見つかりません: $QFDATA_IMG"
    echo "使用方法: $0 <qfdata ファイルのパス>"
    exit 1
fi

if [ ! -f "$SPD_BIN" ] || [ "$REPO_ROOT/spreadtrum_flash/spd_dump.c" -nt "$SPD_BIN" ]; then
    bash "$DIR/build.sh"
fi

echo "=================================================="
echo "  Unisoc UIS7862S - qfdata (液晶ドライバ) 単体フラッシュ"
echo "  Target: $QFDATA_IMG ($(ls -lh "$QFDATA_IMG" | awk '{print $5}'))"
echo "=================================================="
echo ">> 手順:"
echo " 1. 10ピン端子の10番ピンをアンテナ外周(GND)に接触させてキープ"
echo " 2. ナビの電源(12V/ACC)を ON"
echo " 3. 'BootROM ハンドシェイク成功！' が表示されたらピンを離す"
echo "=================================================="
echo "接続待機中 (最大300秒)..."

if [ "$EUID" -ne 0 ]; then
    echo "※注意: USB直接アクセスのため sudo が必要な場合があります。"
fi

"$SPD_BIN" --wait 300 \
    fdl "$FDL1" 0x5500 \
    fdl "$FDL2" 0x9efffe00 \
    disable_transcode \
    timeout 15000 \
    blk_size 0x1000 \
    write_part qfdata "$QFDATA_IMG" \
    reset

echo ""
echo "=================================================="
echo "  [SUCCESS] qfdata の書き込みが完了しました！"
echo "  ナビが自動再起動します。"
echo "=================================================="
