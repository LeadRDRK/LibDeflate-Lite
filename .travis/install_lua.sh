#!/bin/bash
# install an implementation of Lua interpreter

set -eufo pipefail

cd ${TRAVIS_BUILD_DIR}

cd "$LUA_SRC_DIR"
if [[ "$LUA" =~ luajit.* ]]; then
	bash ${TRAVIS_BUILD_DIR}/.travis/install_lua/luajit.sh
elif [[ "$LUA" =~ luaj.* ]]; then
	bash ${TRAVIS_BUILD_DIR}/.travis/install_lua/luaj.sh
elif [[ "$LUA" =~ lua5.* ]]; then
	bash ${TRAVIS_BUILD_DIR}/.travis/install_lua/lua.sh
elif [[ "$LUA" =~ ljx.* ]]; then
	bash ${TRAVIS_BUILD_DIR}/.travis/install_lua/ljx.sh
else
	echo "Don't know how to install $LUA"
	exit 1
fi

cd ${TRAVIS_BUILD_DIR}
