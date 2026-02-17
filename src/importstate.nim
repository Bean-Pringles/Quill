import tables

var importedLibs = initTable[string, bool]()

proc importLib*(name: string) =
    importedLibs[name] = true

proc isImported*(name: string): bool =
    importedLibs.getOrDefault(name, false)

proc clearImports*() =
    importedLibs.clear()