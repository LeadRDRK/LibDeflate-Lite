#!/bin/bash
# helper script o compile and install luajit, luarocks and some libraries

set -eufo pipefail

NAME=luajit

if [[ ! "$LUA" =~  ${NAME}.* ]]; then
	echo "env variable does not match ${NAME}. abort"
	exit 1
fi

VERSION="${LUA/${NAME}/}"
echo ">> Downloading $LUA"
echo "Version: $VERSION"

curl --retry 10 --retry-delay 10 --location https://github.com/LuaJIT/LuaJIT/archive/v$VERSION.tar.gz | tar xz;

cd LuaJIT-$VERSION
echo ">> Compiling $LUA"

make && make install PREFIX="$LUA_HOME_DIR"

ln -s -f luajit-$VERSION $LUA_HOME_DIR/bin/luajit

ln -s -f $LUA_HOME_DIR/bin/luajit $HOME/.lua/luajit
ln -s -f $LUA_HOME_DIR/bin/luajit $HOME/.lua/lua

hash -r
lua -v

echo ">> Downloading luarocks $LUAROCKS"
LUAROCKS_BASE=luarocks-$LUAROCKS
curl --retry 10 --retry-delay 10 --location http://luarocks.org/releases/$LUAROCKS_BASE.tar.gz | tar xz

cd $LUAROCKS_BASE

echo ">> Compiling luarocks $LUAROCKS"
if [[ "$LUA" =~ luajit2\.0.* ]]; then
	./configure --lua-suffix=jit --with-lua-include="$LUA_HOME_DIR/include/luajit-2.0" --prefix="$LR_HOME_DIR";
elif [[ "$LUA" =~ luajit2\.1.* ]]; then
	./configure --lua-suffix=jit --with-lua-include="$LUA_HOME_DIR/include/luajit-2.1" --prefix="$LR_HOME_DIR";
else
	echo "Dont know the include dir of $LUA"
	exit 1
fi

make build && make install

ln -s -f $LR_HOME_DIR/bin/luarocks $HOME/.lua/luarocks
