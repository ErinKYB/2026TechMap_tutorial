#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"

xcrun docc preview "${PROJECT_DIR}/DdiroriTutorial.docc" \
  --fallback-display-name "[TechMap] Spatial Computing 2026 Ddirori" \
  --fallback-bundle-identifier "com.erin.DdiroriTutorial" \
  --fallback-bundle-version "1.0.0" \
  --platform "name=visionOS,version=26.0" \
  --port 8080
