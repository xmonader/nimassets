import
  os,
  strformat,
  strutils,
  base64,
  parseopt,
  threadpool


const buildBranchName* = staticExec("git rev-parse --abbrev-ref HEAD") ## \
  ## `buildBranchName` branch zos is built from
const buildCommit* = staticExec("git rev-parse HEAD")  ## \
  ## `buildCommit` commit zos is built from

# const latestTag* = staticExec("git describe --abbrev=0 --tags") ## \
## `latestTag` latest tag on this branch

const versionString* = &"0.2.1 ({buildBranchName}/{buildCommit})"

const assetsFileHeader = """
import tables, base64

var assets: Table[string, string]

proc getAsset*(path: string): string =
  result = assets[path].decode()

"""

proc handleFile(path: string): string {.thread.} =
  var val, valString: string
  val = readFile(path).encode()
  valString = "\"\"\"" & val & "\"\"\""
  result = &"""assets["{escape(path, prefix="", suffix="")}"] = {valString}""" & "\n\n"

proc generateDirAssetsSimple*(dir: string): string =
  for path in expandTilde(dir).walkDirRec():
    result &= handleFile(path)

proc generateDirAssetsSpawn*(dir: string): string =
  var results = newSeq[FlowVar[string]]()
  for path in expandTilde(dir).walkDirRec():
    results.add(spawn handleFile(path))

  # wait till all of them are done.
  for r in results:
    result &= ^r

# TODO: checks async implementation sometime later..


proc createAssetsFile*(dirs:seq[string], outputfile="assets.nim", fast=false, compress=false) =
  var
    generator: proc(s:string): string
    data = assetsFileHeader

  if fast:
    generator = generateDirAssetsSpawn
  else:
    generator = generateDirAssetsSimple

  for d in dirs:
    data &= generator(d)

  writeFile(outputfile, data)

proc writeHelp() =
  #-c | --compress     : compress
  echo &"""
nimassets {versionString} (Bundle your assets into nim file)
    -h | --help         : show help
    -v | --version      : show version
    -o | --output       : output filename
    -f | --fast         : faster generation
    -d | --dir          : dir to include (recursively)
"""

proc writeVersion() =
  echo &"nimassets version {versionString}"

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

  for directory in dirs:
    if not dirExists(directory):
      echo &"[-] Directory doesnt exist: '{directory}'"
      quit 2 # 2 means dir doesn't exist.
  # echo fmt"compress: {compress} fast: {fast} dirs:{dirs} output:{output}"
  createAssetsFile(dirs, output, fast, compress)

when isMainModule:
  cli()
