#!/usr/bin/env bash
# ==============================================================================
#  Unisoc UIS7862S (ums512) 汎用フラッシュ・メンテナンス CLI ツール
#  - パーティション書き込み (flash)
#  - パーティション吸い出し (backup)
#  - パーティション消去 (erase)
#  - 実機パーティションテーブル取得 (get-partitions)
#  - チップ情報・製造タイムスタンプ取得 (info)
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/.." && pwd)"
SPD_BIN="$REPO_ROOT/spd_dump_usb"
FDL1="$REPO_ROOT/fdl/fdl1-dl.bin"
FDL2="$REPO_ROOT/fdl/fdl2-dl.bin"

# 端末固有データ（IMEI / RF校正 / MACアドレス等）の保護リスト
PROTECTED_PARTS=("l_fixnv1" "l_fixnv2" "l_runtimenv1" "l_runtimenv2" "prodnv" "persist")

# 色設定
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m' # No Color

# ------------------------------------------------------------------------------
# ヘルプ表示
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
${BOLD}====================================================================${NC}
  ${CYAN}Unisoc UIS7862S 汎用フラッシュ・管理ツール (unisoc_tool.sh)${NC}
${BOLD}====================================================================${NC}

${YELLOW}[使い方]${NC}
  sudo ./unisoc_tool.sh <コマンド> [引数...] [オプション]

${YELLOW}[主要コマンド]${NC}
  ${GREEN}flash <パーティション> <イメージパス> [パ2 イメ2 ...]${NC}
      指定したパーティションにイメージファイルを書き込みます。
      複数パーティションを一度に連結書き込みすることも可能です。
      例: sudo ./unisoc_tool.sh flash boot my_boot.img
      例: sudo ./unisoc_tool.sh flash vbmeta stock_vbmeta.img boot stock_boot.img

  ${GREEN}backup <パーティション名> [保存先ファイルパス]${NC}
      実機から任意のパーティションを PC に吸い出してバックアップします。
      保存先を省略した場合は、自動的に日時付きのファイル名が付きます。
      例: sudo ./unisoc_tool.sh backup persist
      例: sudo ./unisoc_tool.sh backup boot boot_backup.img

  ${GREEN}get-partitions [保存先XMLパス]${NC}
      実機 eMMC に記録されている全パーティション名とサイズを取得し、
      XML 保存およびターミナル上に一覧表を表示します。
      例: sudo ./unisoc_tool.sh get-partitions

  ${GREEN}erase <パーティション名>${NC}
      指定したパーティションを完全消去（フォーマット）します。
      例: sudo ./unisoc_tool.sh erase misc

  ${GREEN}info${NC}
      SoC の固有チップ UID および工場出荷 PAC タイムスタンプを取得します。

  ${GREEN}reboot${NC}
      BootROM / FDL モードから通常 Android OS に再起動させます。

${YELLOW}[オプション]${NC}
  ${BOLD}--force${NC}          保護対象パーティション（NV/校正値）への書き込み/消去を強制許可
  ${BOLD}--no-reset${NC}       書き込み/吸い出し完了後、自動再起動を行わず FDL 状態を維持
  ${BOLD}--blk-size <hex>${NC} 転送ブロックサイズを指定 (例: 0x1000 = 4KB, 0x5000 = 20KB)
  ${BOLD}--timeout <ms>${NC}   通信タイムアウト値をミリ秒で指定 (例: 15000, 60000)
  ${BOLD}--wait <秒>${NC}      USB 接続待機タイムアウト (デフォルト: 300秒)
  ${BOLD}-h, --help${NC}        このヘルプを表示

${YELLOW}[注意: 保護対象パーティションについて]${NC}
  ${RED}l_fixnv1, l_fixnv2, l_runtimenv1, l_runtimenv2, prodnv, persist${NC} は
  各個体固有の IMEI 番号や 4G LTE/GPS の高周波校正値、MAC アドレスを含みます。
  これらを誤って破壊すると SIM や Wi-Fi が永久に使用不能になるため、
  書き込み・消去時は ${BOLD}--force${NC} がない限り自動ブロックされます。
EOF
}

# ------------------------------------------------------------------------------
# バイナリと依存関係の確認・自動ビルド
# ------------------------------------------------------------------------------
ensure_binary() {
    if [ ! -f "$SPD_BIN" ] || [ "$REPO_ROOT/spreadtrum_flash/spd_dump.c" -nt "$SPD_BIN" ]; then
        echo -e "${YELLOW}>> spd_dump バイナリを更新/コンパイル中...${NC}"
        bash "$DIR/build.sh"
    fi

    if [ ! -f "$FDL1" ] || [ ! -f "$FDL2" ]; then
        echo -e "${RED}[エラー] FDL1 ($FDL1) または FDL2 ($FDL2) が見つかりません。${NC}"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# ピン操作ガイダンス表示
# ------------------------------------------------------------------------------
print_pin_instructions() {
    echo -e "${BOLD}====================================================================${NC}"
    echo -e "  ${CYAN}Unisoc UIS7862S - ハードウェア接続操作${NC}"
    echo -e "${BOLD}====================================================================${NC}"
    echo -e " ${BOLD}1.${NC} ナビ背面 10ピン端子の ${YELLOW}10番ピン${NC} を アンテナ外周 (GND) に接触させてキープ"
    echo -e " ${BOLD}2.${NC} ナビの電源 (12V / ACC) を ON (または本体 RST ピンを押す)"
    echo -e " ${BOLD}3.${NC} 画面に ${GREEN}'BootROM ハンドシェイク成功！'${NC} が出たら ${RED}${BOLD}即座にピンを離す${NC}"
    echo -e "    ${YELLOW}※ 離すのが遅れると 5秒タイマーで再起動してしまいます。${NC}"
    echo -e "${BOLD}====================================================================${NC}"
    echo -e "接続待機中 (最大 ${WAIT_SEC}秒)..."
}

# ------------------------------------------------------------------------------
# 引数解析
# ------------------------------------------------------------------------------
if [ $# -eq 0 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
    exit 0
fi

CMD="$1"
shift

FORCE=0
NO_RESET=0
WAIT_SEC=300
CUSTOM_BLK_SIZE=""
CUSTOM_TIMEOUT=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --no-reset)
            NO_RESET=1
            shift
            ;;
        --wait)
            WAIT_SEC="$2"
            shift 2
            ;;
        --blk-size)
            CUSTOM_BLK_SIZE="$2"
            shift 2
            ;;
        --timeout)
            CUSTOM_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

ensure_binary

# root 権限チェック
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}※注意: USB 直接アクセスのため sudo が必要な場合があります。${NC}"
fi

# ------------------------------------------------------------------------------
# コマンド別処理
# ------------------------------------------------------------------------------
case "$CMD" in
    flash)
        if [ ${#EXTRA_ARGS[@]} -lt 2 ] || [ $((${#EXTRA_ARGS[@]} % 2)) -ne 0 ]; then
            echo -e "${RED}[エラー] flash には <パーティション名> <イメージパス> のペアが必要です。${NC}"
            echo "例: sudo ./unisoc_tool.sh flash boot my_boot.img"
            exit 1
        fi

        FLASH_OPS=()
        MAX_SZ=0

        for ((i=0; i<${#EXTRA_ARGS[@]}; i+=2)); do
            PART="${EXTRA_ARGS[i]}"
            IMG="${EXTRA_ARGS[i+1]}"

            if [ ! -f "$IMG" ]; then
                echo -e "${RED}[エラー] 書き込みファイルが見つかりません: $IMG${NC}"
                exit 1
            fi

            # 保護パーティションの検査
            for PROT in "${PROTECTED_PARTS[@]}"; do
                if [ "$PART" == "$PROT" ] && [ $FORCE -eq 0 ]; then
                    echo -e "${RED}${BOLD}[警告: 保護領域] パーティション '$PART' は端末固有データ（IMEI / RF校正値）です！${NC}"
                    echo -e "${RED}他人のデータや不整合ファイルを書き込むと SIM や Wi-Fi が永久破損します。${NC}"
                    echo -e "強制的に書き込む場合は ${BOLD}--force${NC} を付けて再実行してください。"
                    exit 1
                fi
            done

            FILE_SZ=$(stat -c%s "$IMG" 2>/dev/null || stat -f%z "$IMG" 2>/dev/null || echo 0)
            if [ "$FILE_SZ" -gt "$MAX_SZ" ]; then
                MAX_SZ="$FILE_SZ"
            fi

            FLASH_OPS+=("write_part" "$PART" "$IMG")
        done

        # 自動パラメータ調整: 50MB 超の場合はブロックサイズとタイムアウトを拡大
        if [ -n "$CUSTOM_BLK_SIZE" ]; then
            BLK_SIZE="$CUSTOM_BLK_SIZE"
        elif [ "$MAX_SZ" -gt 50000000 ]; then
            BLK_SIZE="0x5000" # 20KB (高速大容量モード)
        else
            BLK_SIZE="0x1000" # 4KB (標準モード)
        fi

        if [ -n "$CUSTOM_TIMEOUT" ]; then
            TIMEOUT="$CUSTOM_TIMEOUT"
        elif [ "$MAX_SZ" -gt 50000000 ]; then
            TIMEOUT="60000" # 60秒
        else
            TIMEOUT="15000" # 15秒
        fi

        print_pin_instructions

        CMD_LINE=("$SPD_BIN" "--wait" "$WAIT_SEC"
                  "fdl" "$FDL1" "0x5500"
                  "fdl" "$FDL2" "0x9efffe00"
                  "disable_transcode"
                  "timeout" "$TIMEOUT"
                  "blk_size" "$BLK_SIZE"
                  "${FLASH_OPS[@]}")

        if [ $NO_RESET -eq 0 ]; then
            CMD_LINE+=("reset")
        fi

        "${CMD_LINE[@]}"

        echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
        echo -e "${GREEN}${BOLD}  [SUCCESS] 指定された全パーティションの書き込みが完了しました！${NC}"
        echo -e "${GREEN}${BOLD}====================================================================${NC}"
        ;;

    backup)
        if [ ${#EXTRA_ARGS[@]} -lt 1 ]; then
            echo -e "${RED}[エラー] backup には <パーティション名> が必要です。${NC}"
            echo "例: sudo ./unisoc_tool.sh backup boot [保存先.img]"
            exit 1
        fi

        PART="${EXTRA_ARGS[0]}"
        OUT_FILE="${EXTRA_ARGS[1]:-${PART}_backup_$(date +%Y%m%d_%H%M%S).img}"

        print_pin_instructions

        CMD_LINE=("$SPD_BIN" "--wait" "$WAIT_SEC"
                  "fdl" "$FDL1" "0x5500"
                  "fdl" "$FDL2" "0x9efffe00"
                  "disable_transcode"
                  "timeout" "${CUSTOM_TIMEOUT:-20000}"
                  "blk_size" "${CUSTOM_BLK_SIZE:-0x5000}"
                  "read_part" "$PART" "0" "auto" "$OUT_FILE")

        if [ $NO_RESET -eq 0 ]; then
            CMD_LINE+=("reset")
        fi

        "${CMD_LINE[@]}"

        echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
        echo -e "${GREEN}${BOLD}  [SUCCESS] パーティション '$PART' の吸い出しが完了しました！${NC}"
        echo -e "  保存先: ${CYAN}$OUT_FILE${NC} ($(ls -lh "$OUT_FILE" | awk '{print $5}'))"
        echo -e "${GREEN}${BOLD}====================================================================${NC}"
        ;;

    erase)
        if [ ${#EXTRA_ARGS[@]} -lt 1 ]; then
            echo -e "${RED}[エラー] erase には <パーティション名> が必要です。${NC}"
            exit 1
        fi

        PART="${EXTRA_ARGS[0]}"

        for PROT in "${PROTECTED_PARTS[@]}"; do
            if [ "$PART" == "$PROT" ] && [ $FORCE -eq 0 ]; then
                echo -e "${RED}${BOLD}[警告: 保護領域] パーティション '$PART' は消去できません！${NC}"
                echo -e "消去するとモデムやセンサーの校正値が永久に失われます。"
                echo -e "強制消去する場合は ${BOLD}--force${NC} を付けてください。"
                exit 1
            fi
        done

        print_pin_instructions

        CMD_LINE=("$SPD_BIN" "--wait" "$WAIT_SEC"
                  "fdl" "$FDL1" "0x5500"
                  "fdl" "$FDL2" "0x9efffe00"
                  "disable_transcode"
                  "timeout" "${CUSTOM_TIMEOUT:-30000}"
                  "erase_part" "$PART")

        if [ $NO_RESET -eq 0 ]; then
            CMD_LINE+=("reset")
        fi

        "${CMD_LINE[@]}"

        echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
        echo -e "${GREEN}${BOLD}  [SUCCESS] パーティション '$PART' を消去しました。${NC}"
        echo -e "${GREEN}${BOLD}====================================================================${NC}"
        ;;

    get-partitions)
        OUT_XML="${EXTRA_ARGS[0]:-partitions_$(date +%Y%m%d_%H%M%S).xml}"

        print_pin_instructions

        "$SPD_BIN" --wait "$WAIT_SEC" \
            fdl "$FDL1" 0x5500 \
            fdl "$FDL2" 0x9efffe00 \
            disable_transcode \
            timeout "${CUSTOM_TIMEOUT:-15000}" \
            partition_list "$OUT_XML" \
            $( [ $NO_RESET -eq 0 ] && echo "reset" )

        echo -e "\n${GREEN}${BOLD}====================================================================${NC}"
        echo -e "${GREEN}${BOLD}  [SUCCESS] 実機のパーティションテーブルを取得しました！${NC}"
        echo -e "  保存先XML: ${CYAN}$OUT_XML${NC}"
        echo -e "${GREEN}${BOLD}====================================================================${NC}"

        # Python があれば一覧をテーブル表示
        if command -v python3 >/dev/null 2>&1 && [ -f "$OUT_XML" ]; then
            python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('$OUT_XML')
    root = tree.getroot()
    print('\n' + '='*60)
    print(f' {\"No\":<4} | {\"Partition Name\":<24} | {\"Size (MB)\":>12} ')
    print('='*60)
    idx = 1
    total_sz = 0
    for p in root.findall('Partition'):
        pid = p.attrib.get('id', 'Unknown')
        psz = p.attrib.get('size', '0')
        if psz.startswith('0x'):
            sz_str = 'Full (Remainder)'
        else:
            try:
                sz_mb = int(psz)
                total_sz += sz_mb
                sz_str = f'{sz_mb:,} MB'
            except:
                sz_str = psz
        print(f' {idx:<4} | {pid:<24} | {sz_str:>12} ')
        idx += 1
    print('='*60)
    if total_sz > 0:
        print(f' 検出された固定パーティション合計: {total_sz:,} MB ({total_sz/1024:.2f} GB)\n')
except Exception as e:
    pass
" 2>/dev/null || true
        fi
        ;;

    info)
        print_pin_instructions

        "$SPD_BIN" --wait "$WAIT_SEC" \
            fdl "$FDL1" 0x5500 \
            fdl "$FDL2" 0x9efffe00 \
            disable_transcode \
            chip_uid \
            read_pactime \
            $( [ $NO_RESET -eq 0 ] && echo "reset" )
        ;;

    reboot)
        print_pin_instructions

        "$SPD_BIN" --wait "$WAIT_SEC" \
            fdl "$FDL1" 0x5500 \
            fdl "$FDL2" 0x9efffe00 \
            reset
        ;;

    *)
        echo -e "${RED}[エラー] 不明なコマンド: $CMD${NC}"
        show_help
        exit 1
        ;;
esac
