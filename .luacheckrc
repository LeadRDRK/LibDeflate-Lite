self = false
max_line_length	= 120
max_code_line_length = 120
max_string_line_length = 120
max_comment_line_length = 120

files['.luacheckrc'].global = false
files['*.rockspec'].global = false
files['tests/Test.lua'].global = false

exclude_files = {
    ".release",
    "tests/LibCompress",
    "tests/old_version",
    "tests/third_party"
}

std="min"
