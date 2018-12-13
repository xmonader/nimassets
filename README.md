# nimassets

nimassets `Nim Assets` is heavily inspired by [go-bindata](https://github.com/jteeuwen/go-bindata) to bundle all of your assets into one single nim file.

## Usage
```bash
nimassets 0.1.0 (Bundle your assets into nim file)
    -h | --help         : show help
    -v | --version      : show version
    -o | --output       : output filename
    -f | --fast         : faster generation
    -d | --dir          : dir to include (recursively) [can be used multiple times -d=DIR1 -d=DIR2 ...]
```

### Bundle

To bundle all the files in directory `templatesdir` into single nim file `assetsfile.nim`
```bash
nimassets -d=templatesdir -o=assetsfile.nim
```

`-f` or `--fast` flag can help with large assets directories



### Use Assets
```
import assetsfile

echo assetsfile.getAsset("templatesdir/index.html")
```