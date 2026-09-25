# ResumeKit — run `make help` to see what's available.

# Your resume lives here (gitignored). Falls back to the example until you run `make start`.
MY_RESUME := private/resume.md
ifeq ($(wildcard $(MY_RESUME)),)
SOURCE := resume.md
else
SOURCE := $(MY_RESUME)
endif
PDF := $(SOURCE:.md=.pdf)

VENV := venv
STAMP := $(VENV)/.installed

.DEFAULT_GOAL := help
.PHONY: help setup start resume open example clean

help:
	@echo "ResumeKit"
	@echo ""
	@echo "  make setup    Install everything needed (one time)"
	@echo "  make start    Copy the example to $(MY_RESUME) for you to edit"
	@echo "  make resume   Build your PDF and open it"
	@echo "  make example  Build the example resume.pdf"
	@echo "  make clean    Delete generated files (never touches your .md)"
	@echo ""
	@echo "Currently building: $(SOURCE)"

setup: $(STAMP)
	@command -v pandoc >/dev/null 2>&1 || { \
	  if command -v brew >/dev/null 2>&1; then brew install pandoc; \
	  elif command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y pandoc; \
	  else echo "Please install pandoc: https://pandoc.org/installing.html"; exit 1; fi; }
	@echo "✓ Setup complete. Next: make start"

$(STAMP): requirements.txt
	@if [ "$$(uname)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then brew list pango >/dev/null 2>&1 || brew install pango; fi
	@if command -v apt-get >/dev/null 2>&1 && ! ldconfig -p 2>/dev/null | grep -q libpango-1.0; then sudo apt-get install -y libpango-1.0-0 libpangoft2-1.0-0; fi
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -q -r requirements.txt
	@touch $(STAMP)

start:
	@if [ -f $(MY_RESUME) ]; then echo "$(MY_RESUME) already exists — not overwriting it."; \
	else mkdir -p private && cp resume.md $(MY_RESUME) && echo "✓ Created $(MY_RESUME). Open it in any text editor, then run: make resume"; fi

resume: $(STAMP)
	@./build.sh $(SOURCE)
	@$(MAKE) --no-print-directory open

open:
	@if command -v open >/dev/null 2>&1; then open $(PDF); \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open $(PDF); \
	else echo "Your PDF is at $(PDF)"; fi

example: $(STAMP)
	@./build.sh resume.md

clean:
	rm -rf output *.pdf *.html private/*.pdf private/*.html
