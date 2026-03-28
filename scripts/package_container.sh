#!/usr/bin/env bash
# package_container.sh — Repackage a Wine build into GameHub's libwinemu.so format
#
# Usage:
#   ./package_container.sh x64    <wine_build_dir> <output_name>
#   ./package_container.sh arm64x <wine_build_dir> <output_name>
#
# Examples:
#   ./package_container.sh x64    /tmp/wine-11-x64-android  wine_11.0
#   ./package_container.sh arm64x /tmp/wine-11-arm64-android wine_11.0_arm64x
#
# The wine_build_dir should contain the installed Wine layout:
#   bin/wine, bin/wineserver, lib/wine/x86_64-unix/*.so, etc.
#
# Output: <output_name>.tar.zst  + <output_name>_prefix.tzst
#         + containers_entry.json  (ready to paste into containers.json)

set -euo pipefail

FRAMEWORK="${1:-}"
SRC="${2:-}"
OUT="${3:-}"

if [[ -z "$FRAMEWORK" || -z "$SRC" || -z "$OUT" ]]; then
    echo "Usage: $0 <x64|arm64x> <wine_build_dir> <output_name>"
    exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "[1/5] Checking source directory..."
if [[ "$FRAMEWORK" == "x64" ]]; then
    [[ -f "$SRC/bin/wine" ]] || { echo "ERROR: $SRC/bin/wine not found"; exit 1; }
    file "$SRC/bin/wine" | grep -q "x86-64" || { echo "ERROR: wine binary is not x86-64"; exit 1; }
    file "$SRC/bin/wine" | grep -q "linker64" || { echo "ERROR: wine binary is not Android NDK (missing /system/bin/linker64)"; exit 1; }
    ROOT_DIR="wine_out"
    ARCH_DIR="x86_64"
elif [[ "$FRAMEWORK" == "arm64x" ]]; then
    # wine binary is a symlink to lib/wine/aarch64-unix/wine — check the real binary
    REAL_WINE=$(find "$SRC/lib/wine" -name "wine" -type f 2>/dev/null | head -1)
    [[ -n "$REAL_WINE" ]] || { echo "ERROR: wine binary not found under $SRC/lib/wine/"; exit 1; }
    file "$REAL_WINE" | grep -q "aarch64\|ARM aarch64" || { echo "ERROR: wine binary is not ARM64"; exit 1; }
    file "$REAL_WINE" | grep -q "linker64" || { echo "ERROR: wine binary is not Android NDK (missing /system/bin/linker64)"; exit 1; }
    ROOT_DIR="wine_arm64x_out"
    ARCH_DIR="arm64-v8a"
else
    echo "ERROR: framework must be 'x64' or 'arm64x'"
    exit 1
fi

echo "[2/5] Building main container layout..."
MAIN_STAGE="$WORKDIR/$ROOT_DIR"
mkdir -p "$MAIN_STAGE/$ARCH_DIR/bin" "$MAIN_STAGE/$ARCH_DIR/lib"

# Copy Wine binaries
cp -a "$SRC/bin"    "$MAIN_STAGE/$ARCH_DIR/"
cp -a "$SRC/lib"    "$MAIN_STAGE/$ARCH_DIR/"
[[ -d "$SRC/include" ]] && cp -a "$SRC/include" "$MAIN_STAGE/"
[[ -d "$SRC/share"   ]] && cp -a "$SRC/share"   "$MAIN_STAGE/"

echo "[3/5] Packing main container as $OUT.tar.zst..."
pushd "$WORKDIR" > /dev/null
tar --use-compress-program="zstd -19 -T0" -cf "$OUT.tar.zst" "$ROOT_DIR/"
popd > /dev/null
mv "$WORKDIR/$OUT.tar.zst" "./$OUT.tar.zst"

MAIN_SIZE=$(stat -c%s "./$OUT.tar.zst")
MAIN_MD5=$(md5sum "./$OUT.tar.zst" | cut -d' ' -f1)

echo "[4/5] Building Wine prefix (sub_data)..."
PREFIX_STAGE="$WORKDIR/wine_prefix"
mkdir -p "$PREFIX_STAGE/wine/dosdevices"
mkdir -p "$PREFIX_STAGE/wine/drive_c/windows/system32/drivers/etc"
mkdir -p "$PREFIX_STAGE/wine/drive_c/windows/syswow64"

# Create minimal etc files
cat > "$PREFIX_STAGE/wine/drive_c/windows/system32/drivers/etc/hosts" << 'EOF'
127.0.0.1       localhost
::1             localhost
EOF
cat > "$PREFIX_STAGE/wine/drive_c/windows/system32/drivers/etc/networks" << 'EOF'
loopback        127
EOF
cat > "$PREFIX_STAGE/wine/drive_c/windows/system32/drivers/etc/protocol" << 'EOF'
ip      0       IP
tcp     6       TCP
udp     17      UDP
EOF

SUB_NAME="${MAIN_MD5}.tzst"
pushd "$PREFIX_STAGE" > /dev/null
tar --use-compress-program="zstd -19 -T0" -cf "$SUB_NAME" wine/
popd > /dev/null
mv "$PREFIX_STAGE/$SUB_NAME" "./$SUB_NAME"

SUB_SIZE=$(stat -c%s "./$SUB_NAME")
SUB_MD5=$(md5sum "./$SUB_NAME" | cut -d' ' -f1)

echo "[5/5] Generating containers_entry.json..."
IS_STEAM=2  # 1=Steam/Proton, 2=plain Wine
FRAMEWORK_FIELD="X64"
[[ "$FRAMEWORK" == "arm64x" ]] && FRAMEWORK_FIELD="arm64X"

cat > "./containers_entry_${OUT}.json" << EOF
{
  "id": 99,
  "version": "1.0.0",
  "version_code": 1,
  "name": "${OUT}-${FRAMEWORK_FIELD,,}-1",
  "logo": "https://github.com/The412Banner/bannerhub-api/releases/download/Components/45e60d211d35955bd045aabfded4e64b.png",
  "file_md5": "${MAIN_MD5}",
  "file_size": "${MAIN_SIZE}",
  "download_url": "https://github.com/The412Banner/gamehub-wine/releases/download/Containers/${OUT}.tar.zst",
  "file_name": "${OUT}.tar.zst",
  "framework": "${FRAMEWORK_FIELD}",
  "framework_type": "stable",
  "display_name": "${OUT}-${FRAMEWORK_FIELD,,}-1",
  "is_steam": ${IS_STEAM},
  "sub_data": {
    "sub_file_name": "${SUB_NAME}",
    "sub_download_url": "https://github.com/The412Banner/gamehub-wine/releases/download/Containers/${SUB_NAME}",
    "sub_file_md5": "${SUB_MD5}"
  }
}
EOF

echo ""
echo "Done!"
echo "  Main:     ./${OUT}.tar.zst   (${MAIN_SIZE} bytes, md5=${MAIN_MD5})"
echo "  Sub:      ./${SUB_NAME}  (${SUB_SIZE} bytes, md5=${SUB_MD5})"
echo "  Metadata: ./containers_entry_${OUT}.json"
echo ""
echo "Next steps:"
echo "  1. Upload ./${OUT}.tar.zst and ./${SUB_NAME} to the Containers release"
echo "  2. Copy the JSON entry into bannerhub-api/data/containers.json"
echo "  3. Run 'npm run build' in bannerhub-api and push"
