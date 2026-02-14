package main

import (
	"fmt"
	"image"
	"image/png"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/nfnt/resize"
)

// ---------------- CONFIG ----------------
const (
	EXT           = ".qil"
	TYPE_NAME     = "Quill.Source"
	FRIENDLY_NAME = "Quill Source File"
	BASE_NAME     = "quill"
)

var (
	WINDOWS_SIZES = []int{16, 24, 32, 48, 64, 128, 256}
	LINUX_SIZES   = []int{16, 24, 32, 48, 64, 128, 256, 512}

	SETUP_DIR        string
	SCRIPT_DIR       string
	PROJECT_ROOT     string
	BUILD_SCRIPT_DIR string
	COMPILER_DIR     string
	COMPILER_EXE     string
)

func init() {
	// Get the directory of the current executable/script
	// Script location: ./build/setup/script/<os>/setup
	ex, err := os.Executable()
	if err != nil {
		ex, _ = os.Getwd()
	}
	SETUP_DIR = filepath.Dir(ex)              // ./build/setup/script/<os>
	scriptParent := filepath.Dir(SETUP_DIR)   // ./build/setup/script
	setupParent := filepath.Dir(scriptParent) // ./build/setup
	SCRIPT_DIR = filepath.Dir(setupParent)    // ./build
	PROJECT_ROOT = filepath.Dir(SCRIPT_DIR)   // ./
	BUILD_SCRIPT_DIR = filepath.Join(PROJECT_ROOT, "scripts")

	COMPILER_DIR = getCompilerDir()
	COMPILER_EXE = getCompilerExecutable()
}

func getCompilerDir() string {
	osName := runtime.GOOS
	switch osName {
	case "windows":
		return filepath.Join(SCRIPT_DIR, "compiler", "windows")
	case "linux":
		return filepath.Join(SCRIPT_DIR, "compiler", "linux")
	default:
		panic(fmt.Sprintf("Unsupported OS: %s", osName))
	}
}

func getCompilerExecutable() string {
	osName := runtime.GOOS
	compilerDir := getCompilerDir()

	switch osName {
	case "windows":
		return filepath.Join(compilerDir, "quill-compiler-windows-x86_64.exe")
	case "linux":
		return filepath.Join(compilerDir, "quill-compiler-linux-x86_64")
	default:
		panic(fmt.Sprintf("Unsupported OS: %s", osName))
	}
}

// ----------------------------------------

// ================ LLVM INSTALLATION ================
func installLLVMWindows() bool {
	fmt.Println("[*] Checking for LLVM installation...")

	// Check if LLVM is already installed via llvm-config
	cmd := exec.Command("llvm-config", "--version")
	output, err := cmd.CombinedOutput()
	if err == nil {
		fmt.Printf("[+] LLVM already installed: %s", string(output))
		return true
	}

	// Also check for clang
	cmd = exec.Command("clang", "--version")
	output, err = cmd.CombinedOutput()
	if err == nil {
		parts := strings.Fields(string(output))
		version := "version found"
		if len(parts) > 2 {
			version = parts[2]
		}
		fmt.Printf("[+] Clang/LLVM already installed: %s\n", version)
		fmt.Println("[*] Note: llvm-config not found, but clang is available")
		return true
	}

	fmt.Println("[*] LLVM not found. Installing via winget...")
	cmd = exec.Command("winget", "install", "--id=LLVM.LLVM", "-e")
	err = cmd.Run()
	if err != nil {
		fmt.Printf("[!] Failed to install LLVM via winget: %v\n", err)
		fmt.Println("[*] Please install LLVM manually from https://releases.llvm.org/")
		return false
	}

	fmt.Println("[+] LLVM installed successfully")
	fmt.Println("[!] You may need to restart your terminal for LLVM to be available in PATH")
	return true
}

func installLLVMLinux() bool {
	fmt.Println("[*] Checking for LLVM installation...")

	// Check if LLVM is already installed
	cmd := exec.Command("llvm-config", "--version")
	output, err := cmd.CombinedOutput()
	if err == nil {
		fmt.Printf("[+] LLVM already installed: %s", string(output))
		return true
	}

	fmt.Println("[*] LLVM not found. Attempting to install...")

	// Detect package manager
	var installCmd *exec.Cmd
	if _, err := exec.LookPath("apt-get"); err == nil {
		installCmd = exec.Command("sudo", "apt-get", "install", "-y", "llvm", "clang")
	} else if _, err := exec.LookPath("dnf"); err == nil {
		installCmd = exec.Command("sudo", "dnf", "install", "-y", "llvm", "clang")
	} else if _, err := exec.LookPath("pacman"); err == nil {
		installCmd = exec.Command("sudo", "pacman", "-S", "--noconfirm", "llvm", "clang")
	} else if _, err := exec.LookPath("zypper"); err == nil {
		installCmd = exec.Command("sudo", "zypper", "install", "-y", "llvm", "clang")
	} else {
		fmt.Println("[!] Could not detect package manager")
		fmt.Println("[*] Please install LLVM manually")
		return false
	}

	err = installCmd.Run()
	if err != nil {
		fmt.Printf("[!] Failed to install LLVM: %v\n", err)
		return false
	}

	fmt.Println("[+] LLVM installed successfully")
	return true
}

func installLLVM() bool {
	osName := runtime.GOOS

	switch osName {
	case "windows":
		return installLLVMWindows()
	case "linux":
		return installLLVMLinux()
	default:
		fmt.Printf("[!] Unsupported OS for LLVM installation: %s\n", osName)
		return false
	}
}

// ================ COMPILATION ================
func compileProject() bool {
	osName := runtime.GOOS
	var buildScript string

	if osName == "windows" {
		buildScript = filepath.Join(BUILD_SCRIPT_DIR, "build.bat")
		if _, err := os.Stat(buildScript); os.IsNotExist(err) {
			buildScript = filepath.Join(BUILD_SCRIPT_DIR, "build")
		}
	} else {
		buildScript = filepath.Join(BUILD_SCRIPT_DIR, "build.sh")
		if _, err := os.Stat(buildScript); os.IsNotExist(err) {
			buildScript = filepath.Join(BUILD_SCRIPT_DIR, "build")
		}

		// Make script executable
		fmt.Printf("[*] Making build script executable: %s\n", buildScript)
		if err := os.Chmod(buildScript, 0755); err != nil {
			fmt.Printf("[!] Failed to make script executable: %v\n", err)
			return false
		}
	}

	if _, err := os.Stat(buildScript); os.IsNotExist(err) {
		fmt.Printf("[!] Build script not found at %s\n", BUILD_SCRIPT_DIR)
		return false
	}

	fmt.Printf("[*] Running build script: %s\n", buildScript)

	cmd := exec.Command(buildScript)
	cmd.Dir = BUILD_SCRIPT_DIR
	output, err := cmd.CombinedOutput()

	// Print output, filtering misleading messages
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if !strings.Contains(line, "Process exited with code: Some(1)") {
			fmt.Println(line)
		}
	}

	// Check if compiler executable was created
	if _, err := os.Stat(COMPILER_EXE); err == nil {
		fmt.Println("[+] Compilation successful")
		return true
	}

	fmt.Printf("[!] Compilation failed - compiler executable not found at %s\n", COMPILER_EXE)
	fmt.Printf("[*] Build script exit code: %v\n", err)
	return false
}

// ================ ICON GENERATION ================
func loadImage(path string) (image.Image, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	return img, err
}

func resizeImage(img image.Image, size int) image.Image {
	return resize.Resize(uint(size), uint(size), img, resize.Lanczos3)
}

func makeWindowsIco(img image.Image, outPath string) error {
	// Note: Windows ICO creation in Go requires external library
	// For simplicity, we'll create individual PNGs and suggest using a converter
	// Or use github.com/Kodeworks/golang-image-ico
	fmt.Println("[!] Windows ICO generation requires external tools")
	fmt.Printf("[*] Creating PNG icons in %s directory instead\n", outPath+"_pngs")

	iconDir := outPath + "_pngs"
	os.MkdirAll(iconDir, 0755)

	for _, size := range WINDOWS_SIZES {
		resized := resizeImage(img, size)
		outFile := filepath.Join(iconDir, fmt.Sprintf("%dx%d.png", size, size))

		f, err := os.Create(outFile)
		if err != nil {
			return err
		}
		png.Encode(f, resized)
		f.Close()
	}

	fmt.Printf("[+] Windows icons (PNG): %s/\n", iconDir)
	fmt.Println("[*] Convert to .ico using: magick convert *.png icon.ico")
	return nil
}

func makeLinuxIcons(img image.Image, outDir string) error {
	os.MkdirAll(outDir, 0755)

	for _, size := range LINUX_SIZES {
		resized := resizeImage(img, size)
		outFile := filepath.Join(outDir, fmt.Sprintf("%dx%d.png", size, size))

		f, err := os.Create(outFile)
		if err != nil {
			return err
		}
		png.Encode(f, resized)
		f.Close()
	}

	fmt.Printf("[+] Linux icons: %s/\n", outDir)
	return nil
}

func generateIcons(sourceImage string) error {
	img, err := loadImage(sourceImage)
	if err != nil {
		return err
	}

	osName := runtime.GOOS

	switch osName {
	case "windows":
		return makeWindowsIco(img, filepath.Join(SETUP_DIR, BASE_NAME+".ico"))
	case "linux":
		return makeLinuxIcons(img, filepath.Join(SETUP_DIR, BASE_NAME+"_linux_icons"))
	default:
		return fmt.Errorf("unsupported OS: %s", osName)
	}
}

// ================ FILE TYPE REGISTRATION ================
// registerWindows is in register_windows.go
// registerLinux is below

func registerLinux() error {
	iconDir := filepath.Join(SETUP_DIR, BASE_NAME+"_linux_icons")
	if _, err := os.Stat(iconDir); os.IsNotExist(err) {
		return fmt.Errorf("%s_linux_icons directory not found - run icon generation first", BASE_NAME)
	}

	home, _ := os.UserHomeDir()
	mimeDir := filepath.Join(home, ".local/share/mime/packages")
	iconTarget := filepath.Join(home, ".local/share/icons/hicolor")

	os.MkdirAll(mimeDir, 0755)

	mimeXml := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="text/x-qil">
    <comment>%s</comment>
    <glob pattern="*.qil"/>
  </mime-type>
</mime-info>
`, FRIENDLY_NAME)

	mimeFile := filepath.Join(mimeDir, "qil.xml")
	err := os.WriteFile(mimeFile, []byte(mimeXml), 0644)
	if err != nil {
		return err
	}

	// Update MIME database
	cmd := exec.Command("update-mime-database", filepath.Join(home, ".local/share/mime"))
	cmd.Run()

	// Copy icons
	files, err := os.ReadDir(iconDir)
	if err != nil {
		return err
	}

	for _, file := range files {
		if !strings.HasSuffix(file.Name(), ".png") {
			continue
		}

		// Extract size (e.g., "16x16" from "16x16.png")
		size := strings.TrimSuffix(file.Name(), ".png")
		target := filepath.Join(iconTarget, size, "mimetypes")
		os.MkdirAll(target, 0755)

		// Copy file
		src := filepath.Join(iconDir, file.Name())
		dst := filepath.Join(target, "text-x-qil.png")

		srcFile, err := os.Open(src)
		if err != nil {
			continue
		}

		dstFile, err := os.Create(dst)
		if err != nil {
			srcFile.Close()
			continue
		}

		io.Copy(dstFile, srcFile)
		srcFile.Close()
		dstFile.Close()
	}

	// Update icon cache
	cmd = exec.Command("gtk-update-icon-cache", iconTarget)
	cmd.Stderr = nil
	cmd.Run()

	fmt.Printf("[+] Linux MIME + icon registered for %s\n", EXT)
	return nil
}

// ================ LAUNCHER CREATION ================
func createLauncher() error {
	if _, err := os.Stat(COMPILER_EXE); os.IsNotExist(err) {
		fmt.Printf("[!] Warning: compiler executable not found at %s\n", COMPILER_EXE)
	}

	if runtime.GOOS == "windows" {
		batPath := filepath.Join(PROJECT_ROOT, BASE_NAME+".bat")

		if _, err := os.Stat(batPath); err == nil {
			fmt.Printf("[*] %s.bat already exists, skipping creation.\n", BASE_NAME)
			return nil
		}

		// Calculate relative path
		relPath, _ := filepath.Rel(PROJECT_ROOT, COMPILER_EXE)
		content := fmt.Sprintf("@echo off\n\"%%~dp0%s\" %%*\n", relPath)

		err := os.WriteFile(batPath, []byte(content), 0644)
		if err != nil {
			return err
		}

		fmt.Printf("[+] Created launcher: %s\n", batPath)
	} else {
		shPath := filepath.Join(PROJECT_ROOT, BASE_NAME)

		if _, err := os.Stat(shPath); err == nil {
			fmt.Printf("[*] %s launcher already exists, skipping creation.\n", BASE_NAME)
			return nil
		}

		content := fmt.Sprintf("#!/bin/bash\n\"%s\" \"$@\"\n", COMPILER_EXE)
		err := os.WriteFile(shPath, []byte(content), 0755)
		if err != nil {
			return err
		}

		fmt.Printf("[+] Created launcher: %s\n", shPath)
	}

	return nil
}

// ================ PATH MANAGEMENT ================
func updatePathWindows() error {
	cmd := exec.Command("powershell", "-Command",
		"[Environment]::GetEnvironmentVariable('Path','User')")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return err
	}

	currentPath := strings.TrimSpace(string(output))
	paths := strings.Split(currentPath, ";")

	// Check if already in PATH
	for _, p := range paths {
		if strings.TrimSpace(p) == PROJECT_ROOT {
			fmt.Println("[*] Directory already in PATH.")
			return nil
		}
	}

	// Add to PATH
	newPath := currentPath
	if len(currentPath) > 0 {
		newPath += ";"
	}
	newPath += PROJECT_ROOT

	// Escape for PowerShell
	escapedPath := strings.ReplaceAll(newPath, "'", "''")

	cmd = exec.Command("powershell", "-Command",
		fmt.Sprintf("[Environment]::SetEnvironmentVariable('Path', '%s', 'User')", escapedPath))
	err = cmd.Run()
	if err != nil {
		return err
	}

	fmt.Printf("[+] Added %s to the user PATH.\n", PROJECT_ROOT)
	fmt.Println("[*] Restart your terminal for changes to apply.")
	return nil
}

func updatePathUnix() error {
	home, _ := os.UserHomeDir()

	shell := os.Getenv("SHELL")
	var rcFile string

	if strings.Contains(shell, "zsh") {
		rcFile = filepath.Join(home, ".zshrc")
	} else if strings.Contains(shell, "bash") {
		rcFile = filepath.Join(home, ".bashrc")
	} else {
		rcFile = filepath.Join(home, ".profile")
	}

	pathExport := fmt.Sprintf("export PATH=\"$PATH:%s\"\n", PROJECT_ROOT)

	// Check if already in PATH
	if _, err := os.Stat(rcFile); err == nil {
		content, err := os.ReadFile(rcFile)
		if err == nil && strings.Contains(string(content), PROJECT_ROOT) {
			fmt.Println("[*] Directory already in PATH configuration.")
			return nil
		}
	}

	// Append to rc file
	f, err := os.OpenFile(rcFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = f.WriteString(fmt.Sprintf("\n# Added by Quill installer\n%s", pathExport))
	if err != nil {
		return err
	}

	fmt.Printf("[+] Added %s to PATH in %s\n", PROJECT_ROOT, rcFile)
	fmt.Printf("[*] Run 'source %s' or restart your terminal for changes to apply.\n", rcFile)
	return nil
}

// ================ ARGUMENT PARSING ================
func parseBool(value string) (bool, error) {
	value = strings.ToLower(value)
	switch value {
	case "true", "1", "yes", "y":
		return true, nil
	case "false", "0", "no", "n":
		return false, nil
	default:
		return false, fmt.Errorf("invalid boolean value: %s", value)
	}
}

func printUsage() {
	fmt.Println("Usage: ./setup [install_deps] [register_filetype] [configure_env]")
	fmt.Println("")
	fmt.Println("Arguments (true/false):")
	fmt.Println("  install_deps       - Install LLVM dependencies and compile compiler")
	fmt.Println("  register_filetype  - Generate icons and register .qil file type with OS")
	fmt.Println("  configure_env      - Create launcher and update PATH environment variable")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  ./setup true true true    # Run all steps")
	fmt.Println("  ./setup true false false  # Only install dependencies and compile")
	fmt.Println("  ./setup                   # Run all steps (default)")
}

// ================ MAIN ================
func main() {
	osName := runtime.GOOS

	// Parse command line arguments
	var runInstallDeps, runRegisterFiletype, runConfigureEnv bool

	if len(os.Args) == 1 {
		// Default: all true if no args provided
		runInstallDeps = true
		runRegisterFiletype = true
		runConfigureEnv = true
	} else if len(os.Args) == 2 && (os.Args[1] == "-h" || os.Args[1] == "--help" || os.Args[1] == "help") {
		printUsage()
		return
	} else if len(os.Args) == 4 {
		var err error
		runInstallDeps, err = parseBool(os.Args[1])
		if err != nil {
			fmt.Printf("[!] Error parsing arguments: %v\n", err)
			printUsage()
			os.Exit(1)
		}

		runRegisterFiletype, err = parseBool(os.Args[2])
		if err != nil {
			fmt.Printf("[!] Error parsing arguments: %v\n", err)
			printUsage()
			os.Exit(1)
		}

		runConfigureEnv, err = parseBool(os.Args[3])
		if err != nil {
			fmt.Printf("[!] Error parsing arguments: %v\n", err)
			printUsage()
			os.Exit(1)
		}
	} else {
		fmt.Println("[!] Invalid number of arguments")
		printUsage()
		os.Exit(1)
	}

	fmt.Printf("[*] Detected OS: %s\n", osName)
	fmt.Printf("[*] Project root: %s\n", PROJECT_ROOT)
	fmt.Printf("[*] Compiler directory: %s\n", COMPILER_DIR)
	fmt.Printf("[*] Compiler executable: %s\n", COMPILER_EXE)
	fmt.Println("")

	// Step 1: Install Dependencies (LLVM + Compile Compiler)
	if runInstallDeps {
		fmt.Println("=== INSTALLING DEPENDENCIES ===")

		// Install LLVM
		if !installLLVM() {
			fmt.Println("[!] LLVM installation failed or skipped")
			fmt.Println("[*] Continuing with compilation anyway...")
		}

		fmt.Println("")

		// Compile the compiler
		fmt.Println("=== COMPILING COMPILER ===")
		if !compileProject() {
			fmt.Println("[!] Compilation failed")
			os.Exit(1)
		}

		fmt.Println("")
	} else {
		fmt.Println("[*] Skipping dependency installation and compilation")
		fmt.Println("")
	}

	// Step 2: Register File Type (Generate Icons + Register)
	if runRegisterFiletype {
		fmt.Println("=== GENERATING ICONS ===")
		// Icon source is in the parent directory (./build/setup/script/)
		scriptParent := filepath.Dir(SETUP_DIR)
		iconSource := filepath.Join(scriptParent, "icon.png")

		if _, err := os.Stat(iconSource); os.IsNotExist(err) {
			fmt.Printf("[!] Error: icon.png not found at %s\n", iconSource)
			fmt.Println("[!] Please provide an icon.png file in the ./build/setup/script/ directory")
			fmt.Println("[!] Cannot register file type without icons")
			os.Exit(1)
		}

		err := generateIcons(iconSource)
		if err != nil {
			fmt.Printf("[!] Icon generation failed: %v\n", err)
			fmt.Println("[!] Cannot register file type without icons")
			os.Exit(1)
		}

		fmt.Println("")

		fmt.Println("=== REGISTERING FILE TYPE ===")
		var regErr error

		switch osName {
		case "windows":
			regErr = registerWindows()
		case "linux":
			regErr = registerLinux()
		default:
			fmt.Println("[!] Unsupported OS for file type registration")
			os.Exit(1)
		}

		if regErr != nil {
			fmt.Printf("[!] File type registration failed: %v\n", regErr)
			fmt.Println("[*] You may need to run with elevated privileges")
			os.Exit(1)
		}

		fmt.Println("")
	} else {
		fmt.Println("[*] Skipping icon generation and file type registration")
		fmt.Println("")
	}

	// Step 3: Configure Environment (Create Launcher + Update PATH)
	if runConfigureEnv {
		fmt.Println("=== CREATING LAUNCHER ===")
		err := createLauncher()
		if err != nil {
			fmt.Printf("[!] Failed to create launcher: %v\n", err)
		}
		fmt.Println("")

		fmt.Println("=== UPDATING PATH ===")
		var pathErr error

		if osName == "windows" {
			pathErr = updatePathWindows()
		} else {
			pathErr = updatePathUnix()
		}

		if pathErr != nil {
			fmt.Printf("[!] Failed to update PATH: %v\n", pathErr)
			if osName == "windows" {
				fmt.Printf("[*] Manual setup: Add %s to your user PATH environment variable\n", PROJECT_ROOT)
			} else {
				home, _ := os.UserHomeDir()
				rcFile := filepath.Join(home, ".bashrc")
				fmt.Printf("[*] Manual setup: Add 'export PATH=\"$PATH:%s\"' to your %s\n", PROJECT_ROOT, rcFile)
			}
		}

		fmt.Println("")
	} else {
		fmt.Println("[*] Skipping environment configuration")
		fmt.Println("")
	}

	fmt.Println("[+] Installation complete!")
	fmt.Println("")
}
