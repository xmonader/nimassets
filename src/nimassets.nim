import
  distros,
  os,
  strformat,
  strutils,
  base64,
  zstd/compress,
  parseopt,
  threadpool


const buildBranchName* = staticExec("git rev-parse --abbrev-ref HEAD") ## \
  ## `buildBranchName` branch zos is built from
const buildCommit* = staticExec("git rev-parse HEAD")  ## \
  ## `buildCommit` commit zos is built from

# const latestTag* = staticExec("git describe --abbrev=0 --tags") ## \
## `latestTag` latest tag on this branch

const versionString* = &"0.2.2 ({buildBranchName}/{buildCommit})"

const assetsFileHeaderBinary = """
import tables

var assets: Table[string, seq[byte]]

proc getAsset*(path: string): seq[byte] =
  result = assets[path]

proc getAssetToStr*(path: string): string =
  proc toString(bytes: openArray[byte]): string =
    result = newString(bytes.len)
    copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)
  result = toString(getAsset(path))

"""

const assetsFileHeaderBase64 = """
import tables, base64

var assets: Table[string, string]

proc getAsset*(path: string): string =
  result = assets[path].decode()

func toByteSeq(str: string): seq[byte] {.inline.} =
  ## Copy ``string`` memory into an immutable``seq[byte]``.
  let length = str.len
  if length > 0:
    result = newSeq[byte](length)
    copyMem(result[0].unsafeAddr, str[0].unsafeAddr, length)

proc getAssetToByteSeq*(path: string): string =
  result = toByteSeq (getAsset path)

"""

const assetsFileHeaderZstd = """
import tables, zstd/decompress

var assets: Table[string, seq[byte]]

proc getAsset*(path: string): seq[byte] =
  result = decompress(assets[path])

proc getAssetToStr*(path: string): string =
  proc toString(bytes: openArray[byte]): string =
    result = newString(bytes.len)
    copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)
  result = toString(getAsset(path))

"""

const assetsFileHeaderBase64Zstd = """
import tables, base64, zstd/decompress

var assets: Table[string, string]

func stringToByteSeq(str: string): seq[byte] {.inline.} =
  ## Copy ``string`` memory into an immutable``seq[byte]``.
  let length = str.len
  if length > 0:
    result = newSeq[byte](length)
    copyMem(result[0].unsafeAddr, str[0].unsafeAddr, length)

proc byteArrayToString(bytes: openArray[byte]): string =
  result = newString(bytes.len)
  copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

proc getAsset*(path: string): seq[byte] =
  result = decompress(stringToByteSeq(assets[path].decode()))

proc getAssetToStr*(path: string): string =
  result = byteArrayToString(getAsset path)

"""

type DataType = enum
  tBinary = 1
  tBase64 = 2
  tZstd = 3
  tBase64Zstd = 4

var dataType : DataType = tBase64
var compressLevel : int = 3

proc byteArrayToString(bytes: openArray[byte]): string =
  result = newString(bytes.len)
  copyMem(result[0].addr, bytes[0].unsafeAddr, bytes.len)

func stringToByteSeq(str: string): seq[byte] {.inline.} =
  ## Copy ``string`` memory into an immutable``seq[byte]``.
  let length = str.len
  if length > 0:
    result = newSeq[byte](length)
    copyMem(result[0].unsafeAddr, str[0].unsafeAddr, length)

proc handleFile(path: string): string {.thread.} =
  var val, valString: string

  stdout.write fmt"{path} ... "
  case dataType
  of tBinary:
    let file : File = open(path)
    var input = newSeq[byte](file.getFileSize())
    discard file.readBytes(input, 0, file.getFileSize())
    file.close()
    valString = "@[byte "
    for i, b in input:
      if i < input.len - 1:
        valString &= fmt"0x{toHex(b)},"
      else:
        valString &= fmt"0x{toHex(b)}]"
  of tBase64:
    val = readFile(path).encode()
    valString = "\"\"\"" & val & "\"\"\""
  of tZstd:
    let file : File = open(path)
    var input = newSeq[byte](file.getFileSize())
    discard file.readBytes(input, 0, file.getFileSize())
    file.close()

    stdout.write fmt"zstd-level:{compressLevel} ... "
    let compressed = compress(input, level=compressLevel)

    stdout.write "build_string ... "
    valString = "@[byte "
    for i, b in compressed:
      if i < compressed.len - 1:
        valString &= fmt"0x{toHex(b)},"
      else:
        valString &= fmt"0x{toHex(b)}]"
  of tBase64Zstd:
    # zstd -> byteArrayToString -> base64
    let file : File = open(path)
    var input = newSeq[byte](file.getFileSize())
    discard file.readBytes(input, 0, file.getFileSize())
    file.close()

    val = byteArrayToString(compress(input, level=compressLevel)).encode()
    stdout.write fmt"zstd-level:{compressLevel} ... "
    valString = "\"\"\"" & val & "\"\"\""

  if detectOs(Windows):
    result = &"""assets["{escape(path, prefix="", suffix="")}"] = {valString}""" & "\n\n"
  else:
    result = &"""assets["{path}"] = {valString}""" & "\n\n"
    stdout.write "ok\n"

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
    data =
      case dataType
      of tBinary: assetsFileHeaderBinary
      of tBase64: assetsFileHeaderBase64
      of tZstd: assetsFileHeaderZstd
      of tBase64Zstd: assetsFileHeaderBase64Zstd

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
    -h  | --help          : show help
    -v  | --version       : show version
    -o  | --output        : output filename
    -f  | --fast          : faster generation
    -d  | --dir           : dir to include (recursively)
    -t  | --type          : binary | base64 | zstd | base64zstd
    -cl | --compresslevel : compress level for zstd
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
          of "type", "t": 
            case val
            of "binary":
              dataType = tBinary
            of "base64":
              dataType = tBase64
            of "zstd":
              dataType = tZstd
            of "base64zstd":
              dataType = tBase64Zstd
          of "compresslevel", "cl": compressLevel = parseInt(val)
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
