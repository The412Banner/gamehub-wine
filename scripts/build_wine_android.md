# Building Wine for Android (GameHub NDK format)

## Overview

GameHub uses `winex11.drv` (X11 backend), NOT `wineandroid.drv`.
WineEmu's `libxserver.so` provides the X Window System at runtime.
The container provides Windows PE DLLs + Wine Unix-side ELF .so files.

## What You Need

- Linux build machine (Ubuntu 22.04+ recommended)
- Android NDK r27.3.13750724 (`NDK=/usr/local/lib/android/sdk/ndk/27.3.13750724`)
- Wine source: https://dl.winehq.org/wine/source/11.0/wine-11.0.tar.xz
- FreeType 2.13.3 (cross-compiled for Android)
- ~10GB disk, 16GB RAM recommended

## Container Layout Expected by GameHub

```
wine_out/
  x86_64/           (for X64 containers)
  arm64-v8a/        (for arm64X containers)
    bin/
      wine          (ELF for Android, /system/bin/linker64 interpreter)
      wineserver    (ELF for Android)
    lib/
      wine/
        x86_64-unix/    (ELF .so files — loaded by WineEmu)
        x86_64-windows/ (Windows PE .dll files — used by games)
  share/
  include/
```

## Key Build Notes

### X11 stubs
Box64/FEX wrap `libX11`/`libXext` from imagefs at runtime.
For build-time linking, create Android NDK stubs from host X11 symbols.
Point `--x-includes` to an isolated dir (X11 headers only, NOT `/usr/include`)
to prevent Ubuntu glibc headers from contaminating the NDK compiler path.

### FreeType
Must be cross-compiled for Android NDK — Wine needs it for font rendering.

### android.h patch (Wine 11.0)
`wine-11.0/dlls/wineandroid.drv/android.h` declares `BOOL fullscreen` parameter
but `window.c` removed it. Remove the parameter from the header declaration.

### sched.h patch
`server/thread.c` uses `cpu_set_t`/`CPU_ZERO`/`CPU_SET` but Android NDK configure
doesn't find `sched.h` during cross-compile. Add `#include <sched.h>` manually.

### Makefile patches
- Remove `-Wl,-z,defs` globally — `winex11.so` has unresolved X11 symbols (provided at runtime)
- Remove `dlls/wineandroid.drv/wine-debug.apk` target — jcenter is shut down

### wine binary installation
`make install` does NOT install the `wine`/`wineserver` ELF loader for cross-builds.
Copy manually from `build-x64/loader/wine` → `$prefix/bin/wine`.

### Install prefix layout
`make install` puts everything at `$prefix/` directly (no arch subdir):
```
$prefix/
  bin/wine, wineserver    (manually copied)
  lib/wine/x86_64-unix/   (from make install)
  lib/wine/x86_64-windows/ (from make install)
  share/
```
Pass `$prefix` (not a subdir) as `SRC` to `package_container.sh`.

### arm64X: llvm-mingw required
Ubuntu apt does NOT have `aarch64-w64-mingw32` mingw tools.
Use llvm-mingw: https://github.com/mstorsjo/llvm-mingw/releases

## Sub_data (Wine prefix template)

The `.tzst` sub_data file contains the Windows prefix (registry hives, symlinks).
We reuse wine_10.0's sub_data, removing any `i386-windows` symlinks since Wine 11
is 64-bit only. This gives GameHub's `WinAPI.f()` the registry hives it needs to
initialise a virtual container.

## See Also

The CI workflow `.github/workflows/build-wine.yml` implements all of the above
and uploads artifacts + creates a release automatically.
