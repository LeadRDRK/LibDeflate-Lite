#!/bin/bash
# helper script o compile and install classic Lua interpreter and LuaRocks.

set -eufo pipefail

NAME=lua

echo "Downloading $LUA"
if [[ "$LUA" =~ lua5.* ]]; then
	VERSION="${LUA/${NAME}/}"
	echo "VERSION: $VERSION"
	curl --retry 10 --retry-delay 10 http://www.lua.org/ftp/lua-${VERSION}.tar.gz | tar xz
	cd lua-${VERSION}
else
	echo "$LUA is unknown"
	exit 1
fi

# Build Lua without backwards compatibility for testing
perl -i -pe 's/-DLUA_COMPAT_(ALL|5_2)//' src/Makefile

echo ">> Compiling $LUA"
make $PLATFORM
make INSTALL_TOP="$LUA_HOME_DIR" install

ln -s -f $LUA_HOME_DIR/bin/lua $HOME/.lua/lua
ln -s -f $LUA_HOME_DIR/bin/luac $HOME/.lua/luac

hash -r
lua -v

echo ">> Downloading luarocks $LUAROCKS"
LUAROCKS_BASE=luarocks-$LUAROCKS
curl --retry 10 --retry-delay 10 --location http://luarocks.org/releases/$LUAROCKS_BASE.tar.gz | tar xz

cd $LUAROCKS_BASE

echo ">> Compiling luarocks $LUAROCKS"
./configure --with-lua="$LUA_HOME_DIR" --prefix="$LR_HOME_DIR"

make build && make install

ln -s -f $LR_HOME_DIR/bin/luarocks $HOME/.lua/luarocks
