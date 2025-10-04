# 🧱 AppImage Build Instructions

This guide explains how to correctly prepare and build your
AppImage package.

---

## 📂 Directory Structure Example

```commandline
app_name.AppDir/
├── AppRun
├── app_name.desktop
├── icon_name.png
├── bin/app_name   # your_executable
└── lib/
    ├── Qt6Core.so
    ├── ...
    ├── libz.so
```

---

## ⚙️ What to Include in `usr/lib`

Include only **non-system libraries** like:
- Qt
- zlib
- Other custom dependencies

Do **NOT** include system libraries like:
- `libc.so.6`
- `libm.so.6`
- `libpthread.so.0`
- `libstdc++.so.6`

System libraries must remain linked dynamically from the host OS.

---

## 🧰 Build Script

Use the provided script `build-appimage.sh`. It will:
1. Ask for your AppImage folder path
2. Verify required structure (`AppRun`, `.desktop`, `icon`)
3. Check and download `appimagetool` if missing
4. Build and optionally launch your AppImage

Run it like this:

```bash
chmod +x build-appimage.sh
./build-appimage.sh
```