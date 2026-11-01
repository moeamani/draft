#!/usr/bin/env bash
# Package the game as draft.love (run it with: love draft.love)
set -euo pipefail
cd "$(dirname "$0")/.."
rm -f draft.love
zip -9 -r -q draft.love main.lua conf.lua src assets
echo "built draft.love"
