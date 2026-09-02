#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"

"${SCRIPT_DIR}/build-docs.sh"

cd "${PROJECT_DIR}/.build"
python3 -m http.server 8080
