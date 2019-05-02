# Setup env vars which are determined at runtime.
# Must source this script

# Shouldn't use "set -eufo pipefail"
# in the script which is sourced

if [ -z "${PLATFORM:-}" ]; then
  export PLATFORM=$TRAVIS_OS_NAME;
fi

if [ "$PLATFORM" == "osx" ]; then
  export PLATFORM="macosx";
fi

if [ -z "$PLATFORM" ]; then
  if [ "$(uname)" == "Linux" ]; then
    export PLATFORM="linux";
  else
    export PLATFORM="macosx";
  fi;
fi

mkdir -p $HOME/install
mkdir -p $HOME/.lua
export PATH=${PATH}:$HOME/.lua:$HOME/.local/bin:${HOME}/install/luarocks/bin
export LUA_SRC_DIR=$HOME/luasrc
export LUA_HOME_DIR=$HOME/install/$LUA
export LR_HOME_DIR=$HOME/install/luarocks

mkdir -p "${LUA_SRC_DIR}"
mkdir -p "${LUA_HOME_DIR}"
mkdir -p "${LR_HOME_DIR}"
