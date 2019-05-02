#!/bin/bash
# Install luarocks package, if luarocks exists

set -eufo pipefail

if [[ -n "$(command -v luarocks)" ]]; then
	luarocks --version
	luarocks install luacheck
	luarocks install luaunit
	luarocks install luacov-coveralls
	luarocks install cluacov
	luarocks install ldoc
else
	echo "Skip to install luarocks package because LuaRocks is not installed"
fi