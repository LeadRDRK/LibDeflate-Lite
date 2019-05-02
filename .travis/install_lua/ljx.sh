#!/bin/bash
# helper script o compile and install ljx

NAME=ljx

set -eufo pipefail
if [[ ! "$LUA" =~  ${NAME}.* ]]; then
	echo "env variable does not match ${NAME}. abort"
	exit 1
fi

VERSION="${LUA/${NAME}/}"
echo ">> Downloading $LUA"
echo "lJX version: $VERSION"

curl --retry 10 --retry-delay 10 --location https://github.com/katlogic/ljx/archive/LJX-v${VERSION}.tar.gz | tar xz;

cd ljx-LJX-v$VERSION
echo ">> Compiling $LUA"

make && make install PREFIX="$LUA_HOME_DIR"

ln -s -f $LUA_HOME_DIR/bin/ljx $HOME/.lua/lua

hash -r
lua -v
