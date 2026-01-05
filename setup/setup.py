import os
import sys
import platform
import subprocess
import tempfile

# ---------------- CONFIG ----------------
EXT = ".qil"
TYPE_NAME = "Quill.Source"
FRIENDLY_NAME = "Quill Source File"
BASE_NAME = "quill"

WINDOWS_SIZES = [16, 24, 32, 48, 64, 128, 256]
LINUX_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]
MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024]

SETUP_DIR = os.path.abspath(os.path.dirname(__file__))
SCRIPT_DIR = os.path.abspath(os.path.dirname(SETUP_DIR))  # Parent of setup dir
# ----------------------------------------


# ================ ICON GENERATION ================
def loadImage(path):
    from PIL import Image
    img = Image.open(path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    return img


def makeWindowsIco(img, outPath):
    img.save(outPath, format="ICO", sizes=[(s, s) for s in WINDOWS_SIZES])
    print(f"[+] Windows ICO: {outPath}")


def makeLinuxIcons(img, outDir):
    from PIL import Image
    os.makedirs(outDir, exist_ok=True)
    for size in LINUX_SIZES:
        resized = img.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(outDir, f"{size}x{size}.png"))
    print(f"[+] Linux icons: {outDir}/")


def makeMacosIcns(img, outPath):
    """macOS .icns creation using iconutil"""
    from PIL import Image
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "icon.iconset")
        os.makedirs(iconset)

        for size in MAC_SIZES:
            normal = img.resize((size, size), Image.LANCZOS)
            normal.save(os.path.join(iconset, f"icon_{size}x{size}.png"))

            if size <= 512:
                retina = img.resize((size * 2, size * 2), Image.LANCZOS)
                retina.save(os.path.join(iconset, f"icon_{size}x{size}@2x.png"))

        subprocess.run(
            ["iconutil", "-c", "icns", iconset, "-o", outPath],
            check=True
        )

    print(f"[+] macOS ICNS: {outPath}")


def generateIcons(sourceImage):
    """Generate icons for the current OS only"""
    img = loadImage(sourceImage)
    osName = platform.system()

    if osName == "Windows":
        makeWindowsIco(img, os.path.join(SETUP_DIR, f"{BASE_NAME}.ico"))
    elif osName == "Linux":
        makeLinuxIcons(img, os.path.join(SETUP_DIR, f"{BASE_NAME}_linux_icons"))
    elif osName == "Darwin":
        makeMacosIcns(img, os.path.join(SETUP_DIR, f"{BASE_NAME}.icns"))


# ================ FILE TYPE REGISTRATION ================
def registerWindows():
    """Register .qil file type on Windows"""
    import winreg
    import ctypes

    icoPath = os.path.join(SETUP_DIR, f"{BASE_NAME}.ico")
    if not os.path.exists(icoPath):
        raise FileNotFoundError(f"{BASE_NAME}.ico not found - run icon generation first")

    def setKey(root, path, name, value):
        key = winreg.CreateKey(root, path)
        winreg.SetValueEx(key, name, 0, winreg.REG_SZ, value)
        winreg.CloseKey(key)

    # Register extension
    setKey(winreg.HKEY_CLASSES_ROOT, EXT, "", TYPE_NAME)
    
    # Register type
    setKey(winreg.HKEY_CLASSES_ROOT, TYPE_NAME, "", FRIENDLY_NAME)
    
    # Register icon
    setKey(winreg.HKEY_CLASSES_ROOT, TYPE_NAME + r"\DefaultIcon", "", icoPath)
    
    # Notify Windows of the change
    SHCNE_ASSOCCHANGED = 0x08000000
    SHCNF_IDLIST = 0x0000
    try:
        ctypes.windll.shell32.SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, None, None)
        print(f"[+] Windows registry updated for {EXT}")
        print("[*] Explorer notified - changes should appear immediately")
    except:
        print(f"[+] Windows registry updated for {EXT}")
        print("[!] Could not notify Explorer - you may need to restart Explorer or reboot")


def registerMacos():
    """Register .qil file type on macOS"""
    icnsPath = os.path.join(SETUP_DIR, f"{BASE_NAME}.icns")
    if not os.path.exists(icnsPath):
        raise FileNotFoundError(f"{BASE_NAME}.icns not found - run icon generation first")

    plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>qil</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>{FRIENDLY_NAME}</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleTypeIconFile</key>
            <string>{BASE_NAME}</string>
        </dict>
    </array>
</dict>
</plist>
"""

    with tempfile.TemporaryDirectory() as tmp:
        app = os.path.join(tmp, "QuillIcons.app")
        os.makedirs(os.path.join(app, "Contents", "Resources"))

        with open(os.path.join(app, "Contents", "Info.plist"), "w") as f:
            f.write(plist)

        os.system(f"cp '{icnsPath}' '{app}/Contents/Resources/{BASE_NAME}.icns'")

        subprocess.run([
            "/System/Library/Frameworks/CoreServices.framework"
            "/Frameworks/LaunchServices.framework"
            "/Support/lsregister",
            "-f",
            app
        ])

    print(f"[+] macOS LaunchServices updated for {EXT}")


def registerLinux():
    """Register .qil file type on Linux"""
    iconDir = os.path.join(SETUP_DIR, f"{BASE_NAME}_linux_icons")
    if not os.path.isdir(iconDir):
        raise FileNotFoundError(f"{BASE_NAME}_linux_icons directory not found - run icon generation first")

    mimeDir = os.path.expanduser("~/.local/share/mime/packages")
    appDir = os.path.expanduser("~/.local/share/applications")
    iconTarget = os.path.expanduser("~/.local/share/icons/hicolor")

    os.makedirs(mimeDir, exist_ok=True)
    os.makedirs(appDir, exist_ok=True)

    mimeXml = f"""<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="text/x-qil">
    <comment>{FRIENDLY_NAME}</comment>
    <glob pattern="*.qil"/>
  </mime-type>
</mime-info>
"""

    mimeFile = os.path.join(mimeDir, "qil.xml")
    with open(mimeFile, "w") as f:
        f.write(mimeXml)

    subprocess.run(["update-mime-database", os.path.expanduser("~/.local/share/mime")])

    for file in os.listdir(iconDir):
        size = file.replace(".png", "")
        target = os.path.join(iconTarget, size, "mimetypes")
        os.makedirs(target, exist_ok=True)
        subprocess.run([
            "cp",
            os.path.join(iconDir, file),
            os.path.join(target, "text-x-qil.png")
        ])

    subprocess.run(["gtk-update-icon-cache", iconTarget], stderr=subprocess.DEVNULL)

    print(f"[+] Linux MIME + icon registered for {EXT}")


# ================ LAUNCHER CREATION ================
def createLauncher():
    """Create platform-specific launcher"""
    # Compiler executable is in src directory (sibling to setup)
    compilerDir = os.path.join(SCRIPT_DIR, "src")
    
    if platform.system() == "Windows":
        compilerExe = os.path.join(compilerDir, "compiler.exe")
        batPath = os.path.join(SCRIPT_DIR, f"{BASE_NAME}.bat")
        
        if not os.path.exists(compilerExe):
            print(f"[!] Warning: compiler.exe not found at {compilerExe}")
        
        if os.path.exists(batPath):
            print(f"[*] {BASE_NAME}.bat already exists, skipping creation.")
        else:
            with open(batPath, "w") as f:
                # Use %~dp0 to get the directory where the .bat file is located
                f.write(f'@echo off\n"%~dp0src\\compiler.exe" %*\n')
            print(f"[+] Created launcher: {batPath}")
    else:
        compilerExe = os.path.join(compilerDir, "compiler")
        shPath = os.path.join(SCRIPT_DIR, BASE_NAME)
        
        if not os.path.exists(compilerExe):
            print(f"[!] Warning: compiler executable not found at {compilerExe}")
        
        if os.path.exists(shPath):
            print(f"[*] {BASE_NAME} launcher already exists, skipping creation.")
        else:
            with open(shPath, "w") as f:
                f.write(f'#!/bin/bash\n"{compilerExe}" "$@"\n')
            os.chmod(shPath, 0o755)
            print(f"[+] Created launcher: {shPath}")


# ================ PATH MANAGEMENT ================
def updatePathWindows():
    """Update PATH on Windows"""
    try:
        result = subprocess.run(
            ['powershell', '-Command', 
             '[Environment]::GetEnvironmentVariable("Path","User")'],
            capture_output=True, text=True
        )
        currentPath = result.stdout.strip()
        paths = [p.strip() for p in currentPath.split(";") if p.strip()]
        
        if SCRIPT_DIR not in paths:
            newPath = currentPath + (';' if currentPath else '') + SCRIPT_DIR
            subprocess.run([
                'powershell', '-Command',
                f"[Environment]::SetEnvironmentVariable('Path', '{newPath}', 'User')"
            ], check=True)
            print(f"[+] Added {SCRIPT_DIR} to the user PATH.")
            print("[*] Restart your terminal for changes to apply.")
        else:
            print("[*] Directory already in PATH.")
    except Exception as e:
        print(f"[!] Failed to update PATH: {e}")


def updatePathUnix():
    """Update PATH on Linux/macOS"""
    home = os.path.expanduser("~")
    
    shell = os.environ.get("SHELL", "")
    if "zsh" in shell:
        rcFile = os.path.join(home, ".zshrc")
    elif "bash" in shell:
        rcFile = os.path.join(home, ".bashrc")
    else:
        rcFile = os.path.join(home, ".profile")
    
    pathExport = f'export PATH="$PATH:{SCRIPT_DIR}"\n'
    
    try:
        if os.path.exists(rcFile):
            with open(rcFile, "r") as f:
                content = f.read()
                if SCRIPT_DIR in content:
                    print("[*] Directory already in PATH configuration.")
                    return
        
        with open(rcFile, "a") as f:
            f.write(f"\n# Added by Quill installer\n{pathExport}")
        
        print(f"[+] Added {SCRIPT_DIR} to PATH in {rcFile}")
        print(f"[*] Run 'source {rcFile}' or restart your terminal for changes to apply.")
        
    except Exception as e:
        print(f"[!] Failed to update PATH: {e}")
        print(f"[*] Manual setup: Add 'export PATH=\"$PATH:{SCRIPT_DIR}\"' to your {rcFile}")


# ================ MAIN ================
def main():
    osName = platform.system()
    
    print(f"[*] Detected OS: {osName}")
    print(f"[*] Installation directory: {SCRIPT_DIR}")
    
    # 1. Generate icons
    iconSource = os.path.join(SETUP_DIR, "icon.png")
    if not os.path.exists(iconSource):
        print(f"\n[!] Error: icon.png not found at {iconSource}")
        print("[!] Please provide an icon.png file in the setup directory")
        sys.exit(1)
    
    print("\n=== GENERATING ICONS ===")
    try:
        generateIcons(iconSource)
    except Exception as e:
        print(f"[!] Icon generation failed: {e}")
        sys.exit(1)
    
    # 2. Create launcher
    print("\n=== CREATING LAUNCHER ===")
    createLauncher()
    
    # 3. Update PATH
    print("\n=== UPDATING PATH ===")
    if osName == "Windows":
        updatePathWindows()
    else:
        updatePathUnix()
    
    # 4. Register file type
    print("\n=== REGISTERING FILE TYPE ===")
    try:
        if osName == "Windows":
            registerWindows()
        elif osName == "Darwin":
            registerMacos()
        elif osName == "Linux":
            registerLinux()
        else:
            print("[!] Unsupported OS for file type registration")
            sys.exit(1)
    except Exception as e:
        print(f"[!] File type registration failed: {e}")
        print("[*] You may need to run with elevated privileges")
        sys.exit(1)
    
    print("\n[+] Installation complete!")


if __name__ == "__main__":
    main()
    print("")