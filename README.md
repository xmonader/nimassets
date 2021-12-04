# nimassets

nimassets `Nim Assets` is heavily inspired by [go-bindata](https://github.com/jteeuwen/go-bindata) to bundle all of your assets into one single nim file.

## Usage
```bash
nimassets 0.2.2 (Bundle your assets into nim file)
    -h  | --help          : show help
    -v  | --version       : show version
    -o  | --output        : output filename
    -f  | --fast          : faster generation
    -d  | --dir           : dir to include (recursively) [can be used multiple times -d=DIR1 -d=DIR2 ...]
    -t  | --type          : binary | base64 | zstd | base64zstd
    -cl | --compresslevel : compress level for zstd, default is 3
```

### Bundle

To bundle all the files in directory `templatesdir` from the `examples` folder into single nim file `assetsfile.nim`
```bash
cd examples
nimassets -d=templatesdir -o=assetsfile.nim
```

`-f` or `--fast` flag can help with large assets directories
`-t` or `--type` encoding method, default is base64


### Use Assets
```
import assetsfile # name from -o=<filename>

echo assetsfile.getAsset("templatesdir/index.html")
```

### Development
To run tests, simply do `nimble test` from the root of this repository.

To compile the distributable binary, run `nimble assetsBin`. It will be built and available in `./build/nimassets`.