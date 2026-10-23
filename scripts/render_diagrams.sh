#!/usr/bin/env bash
# Pre-render Mermaid diagrams (diagrams/*.mmd) to PNG (figures/*.png).
# Run locally, then commit figures/ so the server never needs headless Chrome.
#   bash scripts/render_diagrams.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p figures
for f in diagrams/*.mmd; do
  out="figures/$(basename "${f%.mmd}").png"
  echo "Rendering $f -> $out"
  npx --yes @mermaid-js/mermaid-cli@latest -i "$f" -o "$out" -s 4 -b white
done
