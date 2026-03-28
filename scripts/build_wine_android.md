# Building Wine for Android (NDK)

## What You Need

- Linux build machine (Ubuntu 22.04+ recommended)
- Android NDK r27+ (download from developer.android.com/ndk/downloads)
- Wine 11 source: https://gitlab.winehq.org/wine/wine/-/tree/wine-11.0
- ~8GB disk, 16GB RAM recommended

## Step 1: Download NDK

```bash
wget https://dl.google.com/android/repository/android-ndk-r27c-linux.zip
unzip android-ndk-r27c-linux.zip
export NDK=$PWD/android-ndk-r27c
```

## Step 2: Set up cross-compile toolchain

### For X64 (x86-64 Android — runs via Box64)

```bash
export HOST=x86_64-linux-android
export API=28
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64

export CC="$TOOLCHAIN/bin/${HOST}${API}-clang"
export CXX="$TOOLCHAIN/bin/${HOST}${API}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
```

### For arm64X (ARM64 native — no emulation needed)

```bash
export HOST=aarch64-linux-android
export API=28
# ... (same TOOLCHAIN path, different HOST)
export CC="$TOOLCHAIN/bin/${HOST}${API}-clang"
```

## Step 3: Configure Wine

```bash
cd wine-11.0

# You also need a native Wine build for the cross-compilation tools
# Build a host (Linux x86-64) Wine first
mkdir build-host && cd build-host
../configure --enable-win64
make -j$(nproc) __tooldeps__
cd ..

# Now cross-compile for Android
mkdir build-android && cd build-android
../configure \
  --host=$HOST \
  --with-wine-tools=../build-host \
  --prefix=/opt/wine-android \
  --without-x \
  --without-freetype \
  --without-vulkan \
  --enable-android \
  CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"
```

## Step 4: Build and install

```bash
make -j$(nproc)
make install DESTDIR=/tmp/wine-android-out
```

## Step 5: Package with package_container.sh

```bash
./scripts/package_container.sh x64 /tmp/wine-android-out/opt/wine-android wine_11.0
# or
./scripts/package_container.sh arm64x /tmp/wine-android-out/opt/wine-android wine_11.0_arm64x
```

## Notes

- The Wine Android backend (`dlls/wineandroid.drv`) is what makes this work
- `libandroid-spawn.so` is provided by the GameHub imagefs at runtime
- The output Wine binary will have `/system/bin/linker64` as its interpreter
- GameHub's `libwinemu.so` handles launching the Wine process within Android's constraints

## Alternative: Extract from Winlator APK

Winlator bundles pre-built Wine inside its APK. You can extract it:

```bash
# Download Winlator APK from brunodev85/winlator releases
apktool d Winlator_X.X.apk -o winlator_out

# Look for Wine files in assets/ or lib/
find winlator_out -name "wine" -o -name "*.tzst" | head -20
```

However, Winlator's Wine uses a different runtime environment (proot container) and
the binaries may not be compatible with GameHub's libwinemu.so without modifications.
