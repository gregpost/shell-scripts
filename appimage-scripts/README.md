```README.md
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
└── usr/
    ├── bin/app_name   # your_executable
    └── lib/
        ├── lib_name.so
        ├── ...
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

---

## 🧩 Copy ELF and Libraries Script

The script `copy-app-libs.sh` helps you prepare `usr/lib` by copying
all non-system libraries your application requires.

It will:
1. Ask for the path to your executable.
2. Ask if your application uses Qt.
3. Optionally try to launch the executable to detect missing libraries from ELF error logs.
4. Ask for directories to search for missing libraries if detected.
5. Filter out system libraries automatically.
6. Copy all required libraries directly into `usr/lib`.
7. Run `linuxdeployqt` on the executable if it is a Qt application.

Run it like this:

```bash
chmod +x copy-app-libs.sh
./copy-app-libs.sh
```

Follow the interactive prompts and provide the requested paths.
If you press Enter, defaults will be used when shown in `[Y/n]` or `[y/N]` prompts.
```
```
