#!/bin/bash
# Helper script to install LuaJ

set -eufo pipefail

NAME=luaj

if [[ ! "$LUA" =~  ${NAME}.* ]]; then
	echo "env variable does not match ${NAME}. abort"
	exit 1
fi

VERSION="${LUA/${NAME}/}"
echo ">> Downloading $LUA"
echo "Version: $VERSION"

if [[ "$LUA" =~ ${NAME}3 ]]; then
	wget --tries 10 --waitretry 10 https://sourceforge.net/projects/luaj/files/luaj-3.0/${VERSION}/luaj-${VERSION}.zip
elif [[ "$LUA" =~ ${NAME}2 ]]; then
	wget --tries 10 --waitretry 10 https://sourceforge.net/projects/luaj/files/luaj-2.0/${VERSION}/luaj-${VERSION}.zip
else
	echo "Dont know how to handle $LUA"
	exit 1
fi

unzip luaj-${VERSION}.zip

JAR="$(readlink -f luaj-${VERSION}/lib/luaj-jse-${VERSION}.jar)"

echo -e -n '#!/bin/bash\njava -cp '"$JAR"' lua "$@"\n' > $HOME/.lua/lua
chmod +x $HOME/.lua/lua
