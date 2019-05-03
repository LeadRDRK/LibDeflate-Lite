package.path = ("?.lua;")..(package.path or "")
local LibDeflate = require("LibDeflate")package.path = ("?.lua;tests/third_party/?.lua;tests/old_version/?.lua;")
               ..(package.path or "")

local s = "1234"
local compressed = LibDeflate:CompressGzip(s)

local decompressed, err = LibDeflate:DecompressGzip(compressed)
print(compressed:len())
print(decompressed, err)
