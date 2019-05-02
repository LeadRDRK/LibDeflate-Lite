#!/bin/bash
# install an implementation of Lua interpreter

set -eufo pipefail

cd ${WORKDIR}

cd "$LUA_SRC_DIR"
if [[ "$LUA" =~ luajit.* ]]; then
	bash ${WORKDIR}/.travis/install_lua/luajit.sh
elif [[ "$LUA" =~ luaj.* ]]; then
	bash ${WORKDIR}/.travis/install_lua/luaj.sh
elif [[ "$LUA" =~ lua5.* ]]; then
	bash ${WORKDIR}/.travis/install_lua/lua.sh
elif [[ "$LUA" =~ ljx.* ]]; then
	bash ${WORKDIR}/.travis/install_lua/ljx.sh
else
	echo "Don't know how to install $LUA"
	exit 1
fi
