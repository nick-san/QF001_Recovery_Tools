# QF001 Recovery Tools (Unisoc UIS7862S / ums512 Linux Flasher)

Android 車載ナビ **QF001 / UIS7862S（ums512）** の BootROM (BROM) モードを利用した、Linux ネイティブの文鎮化復旧およびパーティション書き込み・吸い出しメンテナンスツールキットです。

Windows 公式ツール（`UpgradeDownload.exe`）をバイナリ解析・リバースエンジニアリングし、Linux PC（x86_64 / aarch64）環境のみで安全かつ高速に復旧が行えるように設計されています。

---

## 🛠️ ディレクトリ構成

* **`scripts/`**:
  * **`unisoc_tool.sh`**: **Unisoc 汎用フラッシュ・メンテナンス CLI ツール**（書き込み・吸い出し・消去・パーティション一覧取得に対応）
  * **`flash_recovery.sh`**: ワンクリック文鎮化復旧スクリプト（`vbmeta` / `vbmeta_bak` / `boot` を一括書き戻し）
  * **`flash_qfdata.sh`**: 液晶ドライバ（`qfdata`）単体書き込み・動作テストスクリプト
  * **`build.sh`**: `spreadtrum_flash` サブモジュールのネイティブコンパイルスクリプト
  * **`99-unisoc-brom.rules`**: 一般ユーザー権限で USB ポートを操作するための udev ルール
* **`fdl/`**: BootROM 起動に必須の FDL ブートローダーバイナリ（`fdl1-dl.bin` / `fdl2-dl.bin`）
* **`spreadtrum_flash/`**: UIS7862S 向けにプロトコル修正を施した BROM フラッシャー（Git サブモジュール）
* **`docs/`**:
  * **`Brick_recovery_manual_JA.pdf`**: 4PDA QF001 文鎮復旧マニュアル（日本語完全翻訳版・写真図解入り）
  * **`Brick_recovery_manual_RU.pdf`**: 4PDA 原版（ロシア語マニュアル）

> [!NOTE]
> ※ 本リポジトリには著作権保護の観点から純正ファームウェアのシステムイメージ（`stock_boot.img` や `stock_vbmeta.img`）は同梱していません。復旧スクリプト実行時はお手持ちのバックアップまたは公式 PAC 等から抽出したイメージをご指定ください。

---

## 🚀 クローンとセットアップ

### 1. リポジトリのクローン（サブモジュール込み）
```bash
git clone --recurse-submodules https://github.com/nick-san/QF001_Recovery_Tools.git
cd QF001_Recovery_Tools

# 既にサブモジュールなしでクローンした場合は:
git submodule update --init --recursive
```

### 2. 依存パッケージのインストール（初回のみ）
GCC と libusb 開発パッケージが必要です。
* **Ubuntu / Debian / Linux Mint:**
  ```bash
  sudo apt update && sudo apt install -y build-essential libusb-1.0-0-dev
  ```
* **Fedora / RHEL / CentOS:**
  ```bash
  sudo dnf install -y gcc libusb1-devel
  ```
* **Arch Linux:**
  ```bash
  sudo pacman -S gcc libusb
  ```

### 3. (推奨) udev ルールの設定
sudo なし（一般ユーザー権限）で USB ポートに直接アクセスできるようにするため、udev ルールを配置します：
```bash
sudo cp scripts/99-unisoc-brom.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

---

## 💻 使い方

### ■ 文鎮化からの復旧（Red Alert・ブートループ時）
```bash
./scripts/flash_recovery.sh <boot.img のパス> <vbmeta.img のパス>

# またはリポジトリ直下に stock_boot.img / stock_vbmeta.img を配置して引数なしで実行:
./scripts/flash_recovery.sh
```

### ■ 液晶ドライバの書き込み（画面真っ暗・テスト時）
```bash
./scripts/flash_qfdata.sh [qfdataのパス]
```

### ■ 汎用フラッシャーツール（unisoc_tool.sh）
```bash
# 1. 任意のパーティションの書き込み
./scripts/unisoc_tool.sh flash boot my_boot.img
./scripts/unisoc_tool.sh flash vbmeta stock_vbmeta.img boot stock_boot.img

# 2. 実機からパーティションの吸い出し (バックアップ)
./scripts/unisoc_tool.sh backup persist           # 固有校正値のバックアップ
./scripts/unisoc_tool.sh backup boot boot_bak.img # boot領域のバックアップ

# 3. 実機の全パーティション名とサイズの取得
./scripts/unisoc_tool.sh get-partitions

# 4. SoC 情報・PAC タイムスタンプの取得
./scripts/unisoc_tool.sh info
```

---

## 🔌 ハードウェア操作手順（10ピン端子）

1. ターミナルに **`接続待機中 (最大300秒)...`** と表示されたら、
2. ナビ背面 10ピン端子の **10番ピン** を アンテナ外周（GND）に接触させたままキープ。
3. ナビの電源（ACC/12V）を ON（または本体 RST ピンを押す）。
4. ターミナルに **`>> BootROM ハンドシェイク成功！`**（または `BSL_REP_VER: "SPRD3\0"`）が表示された瞬間に、**10番ピンを必ず離してください**。
   > [!IMPORTANT]
   > ハンドシェイク成功後も 10番ピンを接地したままにすると、BootROM のハードウェアウォッチドッグタイマー（約5秒）が働き強制再起動します。ハンドシェイク成功が出たら即座に離してください。
5. 書き込み完了後、ナビが自動再起動します。

---

## 📜 クレジット & 免責事項 (Disclaimer)

* **コアフラッシャー**: [Ilya Kurdyukov / spreadtrum_flash](https://github.com/ilyakurdyukov/spreadtrum_flash) (The Unlicense)
  - Unisoc UIS7862S (ums512) 向け修正: [nick-san / spreadtrum_flash](https://github.com/nick-san/spreadtrum_flash)
* **FDL ブートローダーバイナリ (`fdl/`)**: [TheGammaSqueeze / UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) (MIT License)
  - 本パッケージに含まれる FDL バイナリは、緊急時の文鎮化復旧および相互運用性（Interoperability）を目的として提供されています。知的財産権は各製造元（Unisoc / Spreadtrum Communications）に帰属します。
