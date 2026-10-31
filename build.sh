#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════╗"
echo "║     UMac — Build Script      ║"
echo "╚══════════════════════════════╝"
echo ""

# ── Step 0: Terminate existing instances ──
echo "🛑 Stopping any running instances..."
pkill -9 UMac 2>/dev/null || true
pkill -9 DisplayControl 2>/dev/null || true
pkill -9 HyperMac 2>/dev/null || true  # tên cũ trước khi đổi thành UMac
sleep 0.5

# ── Step 1: Build (mặc định: kiến trúc của máy đang build / tuỳ chọn: --universal) ──
BUILD_UNIVERSAL=false
for arg in "$@"; do
    if [ "$arg" = "--universal" ]; then
        BUILD_UNIVERSAL=true
    fi
done

if [ "$BUILD_UNIVERSAL" = "true" ]; then
    echo "🔨 Building UMac (Release - Universal 2: arm64 + x86_64)..."
    mkdir -p .build/bin_arm64 .build/bin_x86_64 .build/release
    echo "  -> Compiling arm64 (Apple Silicon)..."
    swift build -c release --triple arm64-apple-macosx >/dev/null 2>&1 || swift build -c release
    if [ -f ".build/out/Products/Release/UMac" ]; then
        cp .build/out/Products/Release/UMac .build/bin_arm64/UMac
    elif [ -f ".build/release/UMac" ]; then
        cp .build/release/UMac .build/bin_arm64/UMac
    fi

    echo "  -> Compiling x86_64 (Intel)..."
    swift build -c release --triple x86_64-apple-macosx >/dev/null 2>&1 || true
    if [ -f ".build/out/Products/Release/UMac" ]; then
        cp .build/out/Products/Release/UMac .build/bin_x86_64/UMac
    fi

    BINARY=".build/release/UMac"
    if [ -f ".build/bin_arm64/UMac" ] && [ -f ".build/bin_x86_64/UMac" ]; then
        echo "  -> Merging with lipo (Universal 2)..."
        lipo -create .build/bin_arm64/UMac .build/bin_x86_64/UMac -output "$BINARY"
    elif [ -f ".build/bin_arm64/UMac" ]; then
        cp .build/bin_arm64/UMac "$BINARY"
    fi
else
    echo "⚡ Building UMac ($(uname -m))..."
    swift build -c release
    BINARY=".build/release/UMac"
fi

if [ ! -f "$BINARY" ]; then
    echo "❌ Build failed – binary not found."
    exit 1
fi
echo "✅ Build succeeded: $(file "$BINARY")"

# ── Step 2: Create .app bundle ──
APP_NAME="UMac"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "📦 Creating app bundle..."
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

cp "$BINARY" "${MACOS}/"

# Copy Resources (AppIcon.icns, SMC tools, helper scripts)
if [ -d "Resources" ]; then
    echo "🎨 Copying app resources (icon, SMC tools)..."
    cp -R Resources/* "${RESOURCES}/"
    chmod +x "${RESOURCES}/smc" "${RESOURCES}/umac-power" "${RESOURCES}/install-helper.sh" 2>/dev/null || true
fi

# Giấy phép đi kèm bản phân phối (MIT yêu cầu giữ thông báo; smc là GPL-2.0)
cp LICENSE THIRD_PARTY_NOTICES.md "${RESOURCES}/"
cp LICENSES/GPL-2.0.txt "${RESOURCES}/GPL-2.0.txt"

# Info.plist — LSUIElement hides dock icon (menu-bar only)
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>UMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.l3dhung.umac</string>
    <key>CFBundleName</key>
    <string>UMac</string>
    <key>CFBundleDisplayName</key>
    <string>UMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>UMac sử dụng Bluetooth để tự động ngắt kết nối khi gập nắp máy (Sleep Guard), giúp chống tụt pin và chống nóng máy khi ngủ.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>UMac quản lý nguồn Bluetooth khi máy Mac vào chế độ ngủ để tiết kiệm pin.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>UMac cần quyền ghi màn hình để hiển thị ảnh xem trước các cửa sổ trong trình chuyển đổi Alt+Tab.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>UMac sử dụng AppleEvents để điều khiển các ứng dụng và màn hình.</string>
</dict>
</plist>
PLIST

# ── Step 3: Code sign ──
# Dùng chứng chỉ self-signed cố định nếu có (scripts/setup-signing-identity.sh).
# Ký ad-hoc tạo cdhash mới mỗi lần build → macOS thu hồi quyền Accessibility
# sau mỗi lần rebuild. Identity cố định giữ nguyên Designated Requirement.
SIGN_IDENTITY="${UMAC_SIGN_IDENTITY:-UMac Self-Signed}"
SIGN_KEYCHAIN="${UMAC_SIGN_KEYCHAIN:-}"
FIND_ARGS=()
if [[ -n "${SIGN_KEYCHAIN}" ]]; then
    FIND_ARGS=("${SIGN_KEYCHAIN}")
fi
# Không dùng -v: trên runner CI, cert tự ký không được trust nên -v (valid only)
# sẽ báo 0 identity dù vẫn ký được. codesign chỉ cần identity + private key.
if security find-identity -p codesigning "${FIND_ARGS[@]}" 2>/dev/null | grep -qF "${SIGN_IDENTITY}"; then
    echo "🔏 Code signing (${SIGN_IDENTITY})..."
    CODESIGN_ARGS=(--force --deep --sign "${SIGN_IDENTITY}" --identifier "com.l3dhung.umac")
    if [[ -n "${SIGN_KEYCHAIN}" ]]; then
        CODESIGN_ARGS+=(--keychain "${SIGN_KEYCHAIN}")
    fi
    codesign "${CODESIGN_ARGS[@]}" "${APP_DIR}"
else
    echo "🔏 Code signing (ad-hoc — quyền Accessibility sẽ mất sau mỗi lần build)..."
    echo "   → Chạy ./scripts/setup-signing-identity.sh một lần để hết bị."
    codesign --force --deep --sign - --identifier "com.l3dhung.umac" "${APP_DIR}" 2>/dev/null || true
fi

# ── Step 3.1: Create release zip package ──
echo "📦 Packaging ${BUILD_DIR}/UMac.zip for distribution..."
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "${APP_DIR}" "${BUILD_DIR}/UMac.zip"
echo "✅ Package created: ${BUILD_DIR}/UMac.zip"

if [ "$CI" = "true" ] || [ "$1" = "--no-run" ]; then
    echo "📦 CI build completed. Artifact is ready at: ${BUILD_DIR}/UMac.zip"
    exit 0
fi

# ── Step 4: Install to /Applications/ ──
echo "🚀 Installing to /Applications/UMac.app..."
rm -rf /Applications/UMac.app
cp -R "${APP_DIR}" /Applications/UMac.app
rm -rf /Applications/DisplayControl.app /Applications/HyperMac.app 2>/dev/null || true

# ── Step 5: Launch ──
echo "▶️ Launching /Applications/UMac.app..."
open /Applications/UMac.app

sleep 1
PID=$(pgrep -x UMac || true)
if [ -n "$PID" ]; then
    echo "✅ UMac is running with PID: $PID"
else
    echo "⚠️ UMac not detected yet, please check Console."
fi

echo ""
echo "══════════════════════════════════════════"
echo "  ✅  UMac updated & running!"
echo "══════════════════════════════════════════"
echo ""
