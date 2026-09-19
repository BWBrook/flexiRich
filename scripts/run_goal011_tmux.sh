#!/usr/bin/env bash
set -euo pipefail
if [[ $(hostname) != deep-server || -z ${TMUX:-} ]]; then
  printf 'Run on deep-server inside tmux.\n' >&2
  exit 1
fi
run_base=outputs/goal011/forecast-v1
if [[ -e $run_base || -e $run_base.log || -e $run_base.exitcode ]]; then
  printf 'Preserve existing forecast artifacts; use a new frozen run.\n' >&2
  exit 1
fi
mkdir -p outputs/goal011
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
set +e
Rscript scripts/run_goal011_forecasts.R run "$run_base" > "$run_base.log" 2>&1
run_status=$?
set -e
printf '%s\n' "$run_status" > "$run_base.exitcode"
exit "$run_status"
