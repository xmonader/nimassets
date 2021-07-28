# Package

version       = "0.2.1"
author        = "xmonader"
description   = "bundle your assets to a nim"
license       = "MIT"
srcDir        = "src"
binDir        = "build"
bin           = @["nimassets"]
skipDirs      = @["examples", "tests"]


# Dependencies

requires "nim >= 1.4.0"

proc build() =
  exec "nimble build --threads:on -d:release"

task assetsBin, "Build nimassets":
  build()

task buildTemplates, "bundle templates in templatesdir":
  build()
  exec "./build/nimassets -d=examples/templatesdir -o=examples/assetsfile.nim"

task buildTemplatesFast, "bundle templates in templatesdir fast":
  build()
  exec "./build/nimassets -d=examples/templatesdir -o=examples/assetsfilefast.nim -f"

before test:
  build()
  exec "./build/nimassets -d:tests/testassets -o:tests/assetfile.nim"
  exec "./build/nimassets --fast -d:tests/testassets -o:tests/assetfile_fast.nim"