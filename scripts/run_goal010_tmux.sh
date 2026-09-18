#!/usr/bin/env bash
set -euo pipefail
if [[ $(hostname) != deep-server || -z ${TMUX:-} ]]; then
  printf 'Run on deep-server inside tmux.\n' >&2
  exit 1
fi
if [[ ! -f config/goal010_fits.csv ]]; then
  printf 'Run from the frozen repository root.\n' >&2
  exit 1
fi
run_base=outputs/goal010/spatial-v1
if [[ -e $run_base || -e $run_base.log || -e $run_base.exitcode ]]; then
  printf 'Preserve existing run artifacts; use a new frozen run.\n' >&2
  exit 1
fi
mkdir -p outputs/goal010
export MAKEFLAGS=-j2
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
set +e
Rscript scripts/run_goal010_spatial.R run "$run_base" > "$run_base.log" 2>&1
run_status=$?
set -e
printf '%s\n' "$run_status" > "$run_base.exitcode"
exit "$run_status"
