#!/bin/sh
set -eu
game_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$game_dir/GodotSpaceProgram.x86_64" "$@"
