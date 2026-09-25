#!/usr/bin/env bash
#
# Build PDFs from Markdown resumes styled with resume.css
# Usage: ./build.sh [file.md ...]      (defaults to resume.md)
# Most people should just run `make resume` instead (see README).
#
# Requires: pandoc, plus weasyprint installed in ./venv (`make setup` does both)
#
# For each input foo.md, outputs:
#   - foo.pdf (next to the source, current working version)
#   - output/YYYY-MM-DD-HH-mm/foo.pdf (versioned copy)
# Spacing is auto-tuned (via the --fill knob in resume.css) to fill exactly one page;
# it warns if the content cannot fit on one page. FILL=1 ./build.sh disables tuning.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS="${SCRIPT_DIR}/resume.css"
PYTHON="${SCRIPT_DIR}/venv/bin/python"
[[ -x "$PYTHON" ]] || PYTHON=python3

# Sanity checks
command -v pandoc >/dev/null 2>&1 || { echo "Error: pandoc not installed. Run: make setup"; exit 1; }
"$PYTHON" -c "import weasyprint" 2>/dev/null || { echo "Error: weasyprint not installed. Run: make setup"; exit 1; }

if [[ $# -eq 0 ]]; then
    set -- resume.md
fi

# Generate version ID: YYYY-MM-DD-HH-mm
VERSION_ID=$(date +"%Y-%m-%d-%H-%M")
OUTPUT_DIR="${SCRIPT_DIR}/output/${VERSION_ID}"
mkdir -p "${OUTPUT_DIR}"

echo "Building resume version: ${VERSION_ID}"

for SRC in "$@"; do
    [[ -f "$SRC" ]] || { echo "Error: $SRC not found"; exit 1; }
    BASE="${SRC%.md}"
    NAME="$(basename "$BASE")"

    echo "→ Building ${SRC}..."

    # Step 1: Markdown -> HTML (embed CSS)
    pandoc "$SRC" \
        --standalone \
        --css "$CSS" \
        --embed-resources \
        --metadata title=" " \
        -o "${BASE}.html"

    # Step 2: HTML -> PDF. Binary-search the CSS --fill knob for the roomiest
    # spacing that still fits on one page (set FILL=1 to skip and use the CSS as-is).
    RESULT=$(FILL="${FILL:-}" "$PYTHON" - "${BASE}.html" "${BASE}.pdf" 2>/dev/null <<'PY'
import os, sys
from weasyprint import HTML, CSS

html = HTML(sys.argv[1])
MIN_FILL, MAX_FILL = 0.5, 6.0

def render(fill):
    return html.render(stylesheets=[CSS(string=f":root {{ --fill: {fill:.3f} !important }}")])

if os.environ.get("FILL"):
    fill = float(os.environ["FILL"])
    doc = render(fill)
else:
    lo, hi = MIN_FILL, MAX_FILL
    best = render(lo)
    fill = lo
    if len(best.pages) == 1:
        top = render(hi)
        if len(top.pages) == 1:
            best, fill = top, hi
        else:
            for _ in range(10):
                mid = (lo + hi) / 2
                doc = render(mid)
                if len(doc.pages) == 1:
                    lo, best, fill = mid, doc, mid
                else:
                    hi = mid
    doc = best

doc.write_pdf(sys.argv[2])
print(len(doc.pages), f"{fill:.2f}")
PY
)
    read -r PAGES FILL_USED <<< "$RESULT"

    # Copy versioned output
    cp "${BASE}.pdf" "${OUTPUT_DIR}/${NAME}.pdf"

    echo "  ✓ ${BASE}.pdf generated (spacing ×${FILL_USED})"
    echo "  ✓ output/${VERSION_ID}/${NAME}.pdf saved"
    if [[ "$PAGES" -gt 1 ]]; then
        echo "  ⚠ ${BASE}.pdf is ${PAGES} pages even at the tightest spacing — see \"Fit on one page\" in the README"
    fi
done

echo ""
echo "Done! Outputs in: output/${VERSION_ID}/"
