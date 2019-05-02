#!/usr/bin/env false
# Setup env vars which are determined at runtime.
# Must source this script

# Shouldn't use "set -eufo pipefail"
# in the script which is sourced

export WORKDIR="$(pwd)"

echo "Working directory: ${WORKDIR}"

echo "PLATFORM: ${PLATFORM}"  # "Linux" for linux, "Darwin" for macosx

mkdir -p $HOME/install
mkdir -p $HOME/.lua
export PATH=${PATH}:$HOME/.lua:$HOME/.local/bin:${HOME}/install/luarocks/bin
export LUA_SRC_DIR=$HOME/luasrc
export LUA_HOME_DIR=$HOME/install/$LUA
export LR_HOME_DIR=$HOME/install/luarocks

mkdir -p "${LUA_SRC_DIR}"
mkdir -p "${LUA_HOME_DIR}"
mkdir -p "${LR_HOME_DIR}"
