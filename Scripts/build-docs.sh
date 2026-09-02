#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CATALOG_PATH="${PROJECT_DIR}/DdiroriTutorial.docc"
OUTPUT_PATH="${PROJECT_DIR}/.build/2026TechMap_tutorial"

mkdir -p "${PROJECT_DIR}/.build"

xcrun docc convert "${CATALOG_PATH}" \
  --fallback-display-name "[TechMap] Spatial Computing 2026 Ddirori" \
  --fallback-bundle-identifier "com.erin.DdiroriTutorial" \
  --fallback-bundle-version "1.0.0" \
  --platform "name=visionOS,version=26.0" \
  --hosting-base-path "2026TechMap_tutorial" \
  --transform-for-static-hosting \
  --output-path "${OUTPUT_PATH}" \
  --warnings-as-errors

# Xcode 26의 convert 결과에 정적 호스팅용 하위 경로 index.html을 명시적으로 생성합니다.
# 이 단계가 있어야 GitHub Pages에서 튜토리얼 상세 URL을 새로 열거나 새로고침해도 404가 나지 않습니다.
xcrun docc process-archive transform-for-static-hosting "${OUTPUT_PATH}" \
  --hosting-base-path "2026TechMap_tutorial"

# Xcode 26 DocC Render는 Section 첫 코드의 highlights가 비어 있으면
# 해당 Section으로 전환할 때 코드 패널을 빈 화면으로 남길 수 있습니다.
python3 "${SCRIPT_DIR}/fix-tutorial-code-highlights.py" "${OUTPUT_PATH}"

echo "DocC site: ${OUTPUT_PATH}"
