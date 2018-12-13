import os, tables, strformat, base64, ospaths, strutils, parseopt, threadpool


const buildBranchName* = staticExec("git rev-parse --abbrev-ref HEAD") ## \
  ## `buildBranchName` branch zos is built from
const buildCommit* = staticExec("git rev-parse HEAD")  ## \
  ## `buildCommit` commit zos is built from
  
# const latestTag* = staticExec("git describe --abbrev=0 --tags") ## \
## `latestTag` latest tag on this branch

const versionString* = fmt"0.1.0 ({buildBranchName}/{buildCommit})"

let assetsFileHeader = """
import os, tables, strformat, base64, ospaths

var assets = initTable[string, string]()

proc getAsset*(path: string): string = 
  result = assets[path].decode()

"""
proc generateDirAssetsSimple(dir:string): string =
  var key, val, valString: string

  for path in expandTilde(dir).walkDirRec():
    key = path
    val = readFile(path).encode()
    valString = " \"\"\"" & val & "\"\"\" "
    result &= fmt"""assets.add("{path}", {valString})""" & "\n\n"

proc handleFile(path:string): string {.thread.} =
  var val, valString: string
  val = readFile(path).encode()
  valString = " \"\"\"" & val & "\"\"\" "
  result = fmt"""assets.add("{path}", {valString})""" & "\n\n"

proc generateDirAssetsSpawn(dir: string): string = 
  var results = newSeq[FlowVar[string]]()
  for path in expandTilde(dir).walkDirRec():
    results.add(spawn handleFile(path))

  # wait till all of them are done.
  for r in results:
    result &= ^r

# TODO: checks async implementation sometime later..


proc createAssetsFile(dirs:seq[string], outputfile="assets.nim", fast=false, compress=false) =
  var generator: proc(s:string): string
  var data = assetsFileHeader

  if fast:
    generator = generateDirAssetsSpawn
  else:
    generator = generateDirAssetsSimple

  for d in dirs:
    data &= generator(d)
  
  writeFile(outputfile, data)

proc writeHelp() = 
    #-c | --compress     : compress
    echo fmt"""
nimassets {versionString} (Bundle your assets into nim file)
    -h | --help         : show help
    -v | --version      : show version
    -o | --output       : output filename
    -f | --fast         : faster generation
    -d | --dir          : dir to include (recursively)
"""

proc writeVersion() =
    echo fmt"nimassets version {versionString}"

proc cli*() =
  var 
    compress, fast : bool = false
    dirs = newSeq[string]()
    output = "assets.nim"
  
  if paramCount() == 0:
    writeHelp()
    quit(0)
  
  for kind, key, val in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": 
            writeHelp()
            quit()
        of "version", "v":
            writeVersion()
            quit()
        # of "compress", "c": compress= true
        of "fast", "f": fast = true
        of "dir", "d": dirs.add(val)
        of "output", "o": output = val 
        else:
          discard
    else:
      discard 
  for d in dirs:
    if not dirExists(d):
      echo fmt"[-] Directory doesnt exist {d}"
      quit 2 # 2 means dir doesn't exist.
  # echo fmt"compress: {compress} fast: {fast} dirs:{dirs} output:{output}"
  createAssetsFile(dirs, output, fast, compress)

when isMainModule:
  cli()