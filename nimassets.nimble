# Package

version       = "0.1.0"
author        = "xmonader"
description   = "bundle your assets to a nim"
license       = "MIT"
srcDir        = "src"
bin           = @["nimassets"]


# Dependencies

requires "nim >= 0.19.0"

task assetsBin, "Build nimassets":
    exec "nimble build --threads:on"

task buildTemplates, "bundle templates in templatesdir":
    # exec "nimble assetsBin"
    exec "nimassets -d=templatesdir -o=assetsfile.nim"

task buildTemplatesFast, "bundle templates in templatesdir fast":
    # exec "nimble assetsBin"
    exec "nimassets -d=templatesdir -o=assetsfilefast.nim -f"