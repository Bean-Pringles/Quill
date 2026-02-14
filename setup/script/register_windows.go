//go:build windows

package main

import (
	"fmt"
	"os"
	"path/filepath"

	"golang.org/x/sys/windows/registry"
)

func registerWindows() error {
	icoPath := filepath.Join(SETUP_DIR, BASE_NAME+".ico")
	if _, err := os.Stat(icoPath); os.IsNotExist(err) {
		// Try the PNG directory
		icoPath = filepath.Join(SETUP_DIR, BASE_NAME+".ico_pngs")
		if _, err := os.Stat(icoPath); os.IsNotExist(err) {
			return fmt.Errorf("%s.ico not found - run icon generation first", BASE_NAME)
		}
		// Use first PNG as fallback
		icoPath = filepath.Join(icoPath, "32x32.png")
	}

	// Open/Create registry keys
	extKey, _, err := registry.CreateKey(registry.CLASSES_ROOT, EXT, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer extKey.Close()

	err = extKey.SetStringValue("", TYPE_NAME)
	if err != nil {
		return err
	}

	// Register type
	typeKey, _, err := registry.CreateKey(registry.CLASSES_ROOT, TYPE_NAME, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer typeKey.Close()

	err = typeKey.SetStringValue("", FRIENDLY_NAME)
	if err != nil {
		return err
	}

	// Register icon
	iconKey, _, err := registry.CreateKey(registry.CLASSES_ROOT, TYPE_NAME+`\DefaultIcon`, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer iconKey.Close()

	err = iconKey.SetStringValue("", icoPath)
	if err != nil {
		return err
	}

	fmt.Printf("[+] Windows registry updated for %s\n", EXT)
	fmt.Println("[*] You may need to restart Explorer or reboot")
	return nil
}
