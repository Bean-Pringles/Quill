import os
import sys
import platform
import subprocess
import tempfile
import shutil

# ---------------- CONFIG ----------------
EXT = ".qil"
TYPE_NAME = "Quill.Source"
FRIENDLY_NAME = "Quill Source File"
BASE_NAME = "quill"

WINDOWS_SIZES = [16, 24, 32, 48, 64, 128, 256]
LINUX_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]
MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024]

SETUP_DIR = os.path.abspath(os.path.dirname(__file__))
SCRIPT_DIR = os.path.abspath(os.path.dirname(SETUP_DIR))  # Parent of setup dir (build dir)
PROJECT_ROOT = os.path.abspath(os.path.dirname(SCRIPT_DIR))  # Project root
BUILD_SCRIPT_DIR = os.path.join(PROJECT_ROOT, "scripts")

# Determine compiler directory based on platform
def get_compiler_dir():
    osName = platform.system()
    if osName == "Windows":
        return os.path.join(SCRIPT_DIR, "compiler", "windows")
    elif osName == "Linux":
        return os.path.join(SCRIPT_DIR, "compiler", "linux")
    elif osName == "Darwin":
        return os.path.join(SCRIPT_DIR, "compiler", "macos")
    else:
        raise ValueError(f"Unsupported OS: {osName}")

def get_compiler_executable():
    osName = platform.system()
    compilerDir = get_compiler_dir()
    
    if osName == "Windows":
        return os.path.join(compilerDir, "quill-compiler-windows-x86_64.exe")
    elif osName == "Linux":
        return os.path.join(compilerDir, "quill-compiler-linux-x86_64")
    elif osName == "Darwin":
        return os.path.join(compilerDir, "quill-compiler-macos-x86_64")
    else:
        raise ValueError(f"Unsupported OS: {osName}")

COMPILER_DIR = get_compiler_dir()
COMPILER_EXE = get_compiler_executable()
# ----------------------------------------


# ================ DEPENDENCY CHECKS ================
def checkPillowInstalled():
    """Check if Pillow is installed"""
    try:
        import PIL
        return True
    except ImportError:
        print("[!] Pillow (PIL) is not installed")
        print("[*] Install it with: pip install Pillow")
        return False


# ================ LLVM INSTALLATION ================
def installLLVMWindows():
    """Install LLVM on Windows"""
    print("[*] Checking for LLVM installation...")
    
    # Check if LLVM is already installed via llvm-config
    try:
        result = subprocess.run(["llvm-config", "--version"], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[+] LLVM already installed: {result.stdout.strip()}")
            return True
    except FileNotFoundError:
        pass
    
    # Also check for clang (which is often installed without llvm-config)
    try:
        result = subprocess.run(["clang", "--version"], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[+] Clang/LLVM already installed: {result.stdout.split()[2] if len(result.stdout.split()) > 2 else 'version found'}")
            print("[*] Note: llvm-config not found, but clang is available")
            return True
    except FileNotFoundError:
        pass
    
    print("[*] LLVM not found. Installing via winget...")
    try:
        subprocess.run(["winget", "install", "--id=LLVM.LLVM", "-e"], check=True)
        print("[+] LLVM installed successfully")
        print("[!] You may need to restart your terminal for LLVM to be available in PATH")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[!] Failed to install LLVM via winget: {e}")
        print("[*] Please install LLVM manually from https://releases.llvm.org/")
        return False
    except FileNotFoundError:
        print("[!] winget not found. Please install LLVM manually from https://releases.llvm.org/")
        return False


def installLLVMLinux():
    """Install LLVM on Linux"""
    print("[*] Checking for LLVM installation...")
    
    # Check if LLVM is already installed
    try:
        result = subprocess.run(["llvm-config", "--version"], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[+] LLVM already installed: {result.stdout.strip()}")
            return True
    except FileNotFoundError:
        pass
    
    print("[*] LLVM not found. Attempting to install...")
    
    # Detect package manager
    if shutil.which("apt-get"):
        cmd = ["sudo", "apt-get", "install", "-y", "llvm", "clang"]
    elif shutil.which("dnf"):
        cmd = ["sudo", "dnf", "install", "-y", "llvm", "clang"]
    elif shutil.which("pacman"):
        cmd = ["sudo", "pacman", "-S", "--noconfirm", "llvm", "clang"]
    elif shutil.which("zypper"):
        cmd = ["sudo", "zypper", "install", "-y", "llvm", "clang"]
    else:
        print("[!] Could not detect package manager")
        print("[*] Please install LLVM manually")
        return False
    
    try:
        subprocess.run(cmd, check=True)
        print("[+] LLVM installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[!] Failed to install LLVM: {e}")
        return False


def installLLVMMacOS():
    """Install LLVM on macOS"""
    print("[*] Checking for LLVM installation...")
    
    # Check if LLVM is already installed
    try:
        result = subprocess.run(["llvm-config", "--version"], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[+] LLVM already installed: {result.stdout.strip()}")
            return True
    except FileNotFoundError:
        pass
    
    print("[*] LLVM not found. Installing via Homebrew...")
    
    # Check if Homebrew is installed
    if not shutil.which("brew"):
        print("[!] Homebrew not found. Please install from https://brew.sh/")
        return False
    
    try:
        subprocess.run(["brew", "install", "llvm"], check=True)
        print("[+] LLVM installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[!] Failed to install LLVM: {e}")
        return False


def installLLVM():
    """Install LLVM for the current platform"""
    osName = platform.system()
    
    if osName == "Windows":
        return installLLVMWindows()
    elif osName == "Linux":
        return installLLVMLinux()
    elif osName == "Darwin":
        return installLLVMMacOS()
    else:
        print(f"[!] Unsupported OS for LLVM installation: {osName}")
        return False


# ================ COMPILATION ================
def compileProject():
    """Compile the project using platform-specific build script"""
    osName = platform.system()
    
    if osName == "Windows":
        buildScript = os.path.join(BUILD_SCRIPT_DIR, "build.bat")
        if not os.path.exists(buildScript):
            buildScript = os.path.join(BUILD_SCRIPT_DIR, "build")
        
        if not os.path.exists(buildScript):
            print(f"[!] Build script not found at {BUILD_SCRIPT_DIR}")
            return False
        
        expectedExe = COMPILER_EXE
    else:  # Linux/macOS
        buildScript = os.path.join(BUILD_SCRIPT_DIR, "build.sh")
        if not os.path.exists(buildScript):
            buildScript = os.path.join(BUILD_SCRIPT_DIR, "build")
        
        if not os.path.exists(buildScript):
            print(f"[!] Build script not found at {BUILD_SCRIPT_DIR}")
            return False
        
        print(f"[*] Making build script executable: {buildScript}")
        try:
            os.chmod(buildScript, 0o755)
        except Exception as e:
            print(f"[!] Failed to make script executable: {e}")
            return False
        
        expectedExe = COMPILER_EXE
    
    print(f"[*] Running build script: {buildScript}")
    
    # Run the build script - we'll check success by verifying output files
    try:
        result = subprocess.run(
            [buildScript], 
            cwd=BUILD_SCRIPT_DIR,
            capture_output=True,
            text=True
        )
        
        # Print the output for visibility
        if result.stdout:
            # Filter out the misleading "Process exited with code: Some(1)" message
            for line in result.stdout.splitlines():
                if "Process exited with code: Some(1)" not in line:
                    print(line)
        
        # Check if the compiler executable was created (more reliable than exit code)
        if os.path.exists(expectedExe):
            print("[+] Compilation successful")
            return True
        else:
            print(f"[!] Compilation failed - compiler executable not found at {expectedExe}")
            print(f"[*] Build script exit code: {result.returncode}")
            if result.stderr:
                stderr_filtered = '\n'.join(
                    line for line in result.stderr.splitlines() 
                    if "Process exited with code: Some(1)" not in line
                )
                if stderr_filtered.strip():
                    print(f"[*] Error output:\n{stderr_filtered}")
            return False
            
    except Exception as e:
        print(f"[!] Failed to run build script: {e}")
        return False


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

    try:
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
        except Exception as e:
            print(f"[+] Windows registry updated for {EXT}")
            print(f"[!] Could not notify Explorer: {e}")
            print("[*] You may need to restart Explorer or reboot")
    except Exception as e:
        print(f"[!] Failed to update Windows registry: {e}")
        raise


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

        # Use subprocess instead of os.system for better error handling
        subprocess.run([
            "cp", icnsPath, 
            os.path.join(app, "Contents", "Resources", f"{BASE_NAME}.icns")
        ], check=True)

        # Fixed path - properly joined
        lsregister_path = os.path.join(
            "/System/Library/Frameworks/CoreServices.framework",
            "Frameworks/LaunchServices.framework",
            "Support/lsregister"
        )
        
        subprocess.run([lsregister_path, "-f", app], check=True)

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

    subprocess.run(["update-mime-database", os.path.expanduser("~/.local/share/mime")], check=True)

    # Fixed icon copying logic
    for file in os.listdir(iconDir):
        if not file.endswith(".png"):
            continue
            
        # Extract size (e.g., "16x16" from "16x16.png")
        size = file.replace(".png", "")
        target = os.path.join(iconTarget, size, "mimetypes")
        os.makedirs(target, exist_ok=True)
        
        subprocess.run([
            "cp",
            os.path.join(iconDir, file),
            os.path.join(target, "text-x-qil.png")
        ], check=True)

    subprocess.run(["gtk-update-icon-cache", iconTarget], stderr=subprocess.DEVNULL)

    print(f"[+] Linux MIME + icon registered for {EXT}")


# ================ LAUNCHER CREATION ================
def createLauncher():
    """Create platform-specific launcher"""
    if platform.system() == "Windows":
        batPath = os.path.join(PROJECT_ROOT, f"{BASE_NAME}.bat")
        
        if not os.path.exists(COMPILER_EXE):
            print(f"[!] Warning: compiler executable not found at {COMPILER_EXE}")
        
        if os.path.exists(batPath):
            print(f"[*] {BASE_NAME}.bat already exists, skipping creation.")
        else:
            # Calculate relative path from project root to compiler
            relPath = os.path.relpath(COMPILER_EXE, PROJECT_ROOT)
            with open(batPath, "w") as f:
                # Use %~dp0 to get the directory where the .bat file is located
                f.write(f'@echo off\n"%~dp0{relPath}" %*\n')
            print(f"[+] Created launcher: {batPath}")
    else:
        shPath = os.path.join(PROJECT_ROOT, BASE_NAME)
        
        if not os.path.exists(COMPILER_EXE):
            print(f"[!] Warning: compiler executable not found at {COMPILER_EXE}")
        
        if os.path.exists(shPath):
            print(f"[*] {BASE_NAME} launcher already exists, skipping creation.")
        else:
            with open(shPath, "w") as f:
                f.write(f'#!/bin/bash\n"{COMPILER_EXE}" "$@"\n')
            os.chmod(shPath, 0o755)
            print(f"[+] Created launcher: {shPath}")


# ================ PATH MANAGEMENT ================
def updatePathWindows():
    """Update PATH on Windows"""
    try:
        result = subprocess.run(
            ['powershell', '-Command', 
             '[Environment]::GetEnvironmentVariable("Path","User")'],
            capture_output=True, text=True, check=True
        )
        currentPath = result.stdout.strip()
        paths = [p.strip() for p in currentPath.split(";") if p.strip()]
        
        if PROJECT_ROOT not in paths:
            newPath = currentPath + (';' if currentPath else '') + PROJECT_ROOT
            # Properly escape the path for PowerShell
            escapedPath = newPath.replace("'", "''")
            subprocess.run([
                'powershell', '-Command',
                f"[Environment]::SetEnvironmentVariable('Path', '{escapedPath}', 'User')"
            ], check=True)
            print(f"[+] Added {PROJECT_ROOT} to the user PATH.")
            print("[*] Restart your terminal for changes to apply.")
        else:
            print("[*] Directory already in PATH.")
    except Exception as e:
        print(f"[!] Failed to update PATH: {e}")
        print(f"[*] Manual setup: Add {PROJECT_ROOT} to your user PATH environment variable")


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
    
    pathExport = f'export PATH="$PATH:{PROJECT_ROOT}"\n'
    
    try:
        if os.path.exists(rcFile):
            with open(rcFile, "r") as f:
                content = f.read()
                if PROJECT_ROOT in content:
                    print("[*] Directory already in PATH configuration.")
                    return
        
        with open(rcFile, "a") as f:
            f.write(f"\n# Added by Quill installer\n{pathExport}")
        
        print(f"[+] Added {PROJECT_ROOT} to PATH in {rcFile}")
        print(f"[*] Run 'source {rcFile}' or restart your terminal for changes to apply.")
        
    except Exception as e:
        print(f"[!] Failed to update PATH: {e}")
        print(f"[*] Manual setup: Add 'export PATH=\"$PATH:{PROJECT_ROOT}\"' to your {rcFile}")


# ================ ARGUMENT PARSING ================
def parseBool(value):
    """Parse string to boolean"""
    if isinstance(value, bool):
        return value
    return value.lower() in ('true', '1', 'yes', 'y')


def printUsage():
    """Print usage information"""
    print("Usage: python setup.py [install_deps] [register_filetype] [configure_env]")
    print("")
    print("Arguments (True/False):")
    print("  install_deps       - Install LLVM dependencies and compile compiler")
    print("  register_filetype  - Generate icons and register .qil file type with OS")
    print("  configure_env      - Create launcher and update PATH environment variable")
    print("")
    print("Examples:")
    print("  python setup.py True True True    # Run all steps")
    print("  python setup.py True False False  # Only install dependencies and compile")
    print("  python setup.py                   # Run all steps (default)")


# ================ MAIN ================
def main():
    osName = platform.system()
    
    # Parse command line arguments
    # Default: all True if no args provided
    if len(sys.argv) == 1:
        runInstallDeps = True
        runRegisterFiletype = True
        runConfigureEnv = True
    elif len(sys.argv) == 2 and sys.argv[1] in ['-h', '--help', 'help']:
        printUsage()
        return
    elif len(sys.argv) == 4:
        try:
            runInstallDeps = parseBool(sys.argv[1])
            runRegisterFiletype = parseBool(sys.argv[2])
            runConfigureEnv = parseBool(sys.argv[3])
        except Exception as e:
            print(f"[!] Error parsing arguments: {e}")
            printUsage()
            sys.exit(1)
    else:
        print("[!] Invalid number of arguments")
        printUsage()
        sys.exit(1)
    
    print(f"[*] Detected OS: {osName}")
    print(f"[*] Project root: {PROJECT_ROOT}")
    print(f"[*] Compiler directory: {COMPILER_DIR}")
    print(f"[*] Compiler executable: {COMPILER_EXE}")
    print("")
    
    # Step 1: Install Dependencies (LLVM + Compile Compiler)
    if runInstallDeps:
        print("=== INSTALLING DEPENDENCIES ===")
        
        # Install LLVM
        if not installLLVM():
            print("[!] LLVM installation failed or skipped")
            print("[*] Continuing with compilation anyway...")
        
        print("")
        
        # Compile the compiler
        print("=== COMPILING COMPILER ===")
        if not compileProject():
            print("[!] Compilation failed")
            sys.exit(1)
        
        print("")
    else:
        print("[*] Skipping dependency installation and compilation")
        print("")
    
    # Step 2: Register File Type (Generate Icons + Register)
    if runRegisterFiletype:
        # Check for Pillow before attempting icon generation
        if not checkPillowInstalled():
            print("[!] Cannot generate icons without Pillow")
            print("[!] Install Pillow and run again with: python setup.py False True False")
            sys.exit(1)
        
        print("=== GENERATING ICONS ===")
        iconSource = os.path.join(SETUP_DIR, "icon.png")
        
        if not os.path.exists(iconSource):
            print(f"[!] Error: icon.png not found at {iconSource}")
            print("[!] Please provide an icon.png file in the setup directory")
            print("[!] Cannot register file type without icons")
            sys.exit(1)
        
        try:
            generateIcons(iconSource)
        except Exception as e:
            print(f"[!] Icon generation failed: {e}")
            print("[!] Cannot register file type without icons")
            sys.exit(1)
        
        print("")
        
        print("=== REGISTERING FILE TYPE ===")
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
        print("")
    else:
        print("[*] Skipping icon generation and file type registration")
        print("")
    
    # Step 3: Configure Environment (Create Launcher + Update PATH)
    if runConfigureEnv:
        print("=== CREATING LAUNCHER ===")
        createLauncher()
        print("")
        
        print("=== UPDATING PATH ===")
        if osName == "Windows":
            updatePathWindows()
        else:
            updatePathUnix()
        print("")
    else:
        print("[*] Skipping environment configuration")
        print("")
    
    print("[+] Installation complete!")
    print("")


if __name__ == "__main__":
    main()