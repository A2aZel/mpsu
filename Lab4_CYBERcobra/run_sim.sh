#!/usr/bin/env bash
set -eu
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec vivado -mode batch -nojournal -nolog -source "$script_dir/build_sim.tcl" -tclargs "${1:-default}" "${2:-directed}"
