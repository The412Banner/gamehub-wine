# gamehub-wine

Custom Wine/Proton containers for GameHub and BannerHub, packaged in the `libwinemu.so` format.

## Container Format

GameHub uses two container types, identified by the `framework` field:

### X64 (Wine x86-64 via Box64/FEX emulation)

```
wine_out/
├── x86_64/
│   ├── bin/         # wine, wineserver, wineboot, msiexec, etc. (x86-64 Android NDK ELFs)
│   └── lib/
│       └── wine/
│           ├── i386-windows/    # 32-bit Windows PE DLLs
│           ├── x86_64-unix/     # Unix-side .so modules (x86-64 Android NDK)
│           └── x86_64-windows/  # 64-bit Windows PE DLLs
├── include/         # Wine headers (not required at runtime)
└── share/           # Wine data files (fonts, etc.)
```

### arm64X (Native ARM64 Wine — no Box64 overhead)

```
wine_arm64x_out/
├── arm64-v8a/
│   ├── bin/         # wine → symlink to ../lib/wine/aarch64-unix/wine
│   └── lib/
│       └── wine/
│           └── aarch64-unix/    # ARM64 Android NDK ELFs
├── include/
└── share/
```

### Sub-data file (Wine prefix — same for both types)

A separate `.tzst` (tar+zstd) with a clean Wine prefix:
```
wine/
├── dosdevices/
└── drive_c/
    └── windows/
        ├── system32/
        │   └── drivers/
        └── syswow64/
```

## Build Requirements

All Wine binaries must be compiled with **Android NDK** (not standard Linux):
- Interpreter: `/system/bin/linker64` (NOT `/lib64/ld-linux-x86-64.so.2`)
- Target: Android API 28+
- NDK: r26b or later
- Tested: NDK clang 17 (r26b/r27)

This requires building Wine with the Android NDK toolchain and the `--host=x86_64-linux-android` (X64) or `--host=aarch64-linux-android` (arm64X) flags.

## Container Metadata (containers.json fields)

| Field | Values | Notes |
|-------|--------|-------|
| `framework` | `X64` / `arm64X` | Determines root dir + binary arch |
| `framework_type` | `stable` | Always stable for releases |
| `is_steam` | `1` (Steam/Proton) / `2` (plain Wine) | Controls Wine vs Proton icon in UI |
| `file_name` | `wine_X.X.tar.zst` | Main container archive |
| `sub_data.sub_file_name` | `{md5}.tzst` | Wine prefix archive |

## Packaging Script

See `scripts/package_container.sh` — takes an extracted Wine build directory, repackages it to the correct layout, and computes MD5/size for containers.json.

## Target: Wine 11

Wine 11.0 (January 2025) is the target for this repo. Requires building from:
- Source: https://gitlab.winehq.org/wine/wine/-/tree/wine-11.0
- Build system: Android NDK r27+ with `configure --host=x86_64-linux-android`

## Known Working Sources

| Container | Wine Version | Framework | Source |
|-----------|-------------|-----------|--------|
| wine_10.0 | 10.0 | X64 | gamehublite/gamehub_api |
| wine_10.6_arm64x | 10.6 | arm64X | gamehublite/gamehub_api |
| wine_proton10.0_x64 | Proton 10.0 | X64 | gamehublite/gamehub_api |
