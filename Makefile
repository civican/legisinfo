.PHONY: help run docker-run scrape fix-encoding reset reset-confirm

# Source for the legisinfo-server package.
# By default, points to the sibling directory. Can be overridden with a git URL:
# make run LEGISINFO_SERVER_SOURCE=git+https://github.com/mlhamel/legisinfo-server.git
LEGISINFO_SERVER_SOURCE ?= ../legisinfo-server
DOCKER_IMAGE ?= legisinfo-server:latest

# Source for the civican-scraper package.
# By default, points to the sibling directory. Can be overridden with a git URL:
# make scrape CIVICAN_SCRAPER_SOURCE=git+https://github.com/civican/civican-scraper.git
CIVICAN_SCRAPER_SOURCE ?= ../civican-scraper
CRAWLER ?= legisinfo
SESSION ?= active
LIMIT ?= 0
EXTRA_FLAGS ?=

ifeq ($(SESSION),active)
  SESSION_ARG =
else
  SESSION_ARG = --session $(SESSION)
endif

ifneq ($(LIMIT),0)
  LIMIT_ARG = --limit $(LIMIT)
else
  LIMIT_ARG =
endif

help:
	@echo "Available commands:"
	@echo "  run          - Ephemerally fetch, install and run the API server using uv"
	@echo "  docker-run   - Run the API server via Docker mounting current directory as data"
	@echo "  scrape       - Ephemerally fetch, install and run the scraper targeting this repo using uv"
	@echo "                 Usage: make scrape [CRAWLER=legisinfo] [SESSION=active|all|45-1] [LIMIT=10] [EXTRA_FLAGS=--dry-run]"
	@echo "  fix-encoding - Scan and repair Mojibake/encoding issues in all existing repository documents in-place"
	@echo "  reset        - Show instructions for clearing all scraped bill data and resetting Git history"
	@echo "  reset-confirm- Perform reset of bill data and collapse Git history to a clean initial commit"

run:
	@if echo "$(LEGISINFO_SERVER_SOURCE)" | grep -q "git+"; then \
		echo "Fetching and running from remote: $(LEGISINFO_SERVER_SOURCE)..."; \
		LEGISINFO_DATA_PATH=$$(pwd) uv run --with "legisinfo-server @ $(LEGISINFO_SERVER_SOURCE)" -- uvicorn legisinfo_server.main:app --host 0.0.0.0 --port 8001; \
	else \
		LEGISINFO_DATA_PATH=$$(pwd) uv run --no-cache --with "legisinfo-server @ file://$$(realpath $(LEGISINFO_SERVER_SOURCE))" -- uvicorn legisinfo_server.main:app --host 0.0.0.0 --port 8001; \
	fi

docker-run:
	@echo "Running API server container mounting current directory..."
	docker run --rm -it -p 8001:8000 -v $$(pwd):/data -e LEGISINFO_DATA_PATH=/data $(DOCKER_IMAGE)

scrape:
	@if echo "$(CIVICAN_SCRAPER_SOURCE)" | grep -q "git+"; then \
		echo "Fetching and running scraper from remote: $(CIVICAN_SCRAPER_SOURCE)..."; \
		uv run --with "civican-scraper @ $(CIVICAN_SCRAPER_SOURCE)" -- civican-scraper $(CRAWLER) --repo $$(pwd) $(SESSION_ARG) $(LIMIT_ARG) $(EXTRA_FLAGS); \
	else \
		uv run --no-cache --with "civican-scraper @ file://$$(realpath $(CIVICAN_SCRAPER_SOURCE))" -- civican-scraper $(CRAWLER) --repo $$(pwd) $(SESSION_ARG) $(LIMIT_ARG) $(EXTRA_FLAGS); \
	fi

fix-encoding:
	@if echo "$(CIVICAN_SCRAPER_SOURCE)" | grep -q "git+"; then \
		uv run --with "civican-scraper @ $(CIVICAN_SCRAPER_SOURCE)" -- legisinfo-fix-encoding --repo $$(pwd); \
	else \
		uv run --no-cache --with "civican-scraper @ file://$$(realpath $(CIVICAN_SCRAPER_SOURCE))" -- legisinfo-fix-encoding --repo $$(pwd); \
	fi

reset:
	@echo "WARNING: This will completely wipe all scraped bill data and reset Git history to a single initial commit!"
	@echo "Preserved: Makefile, LICENSE.md, README.md (cleared index), and .github/"
	@echo "To proceed, run: make reset-confirm"

reset-confirm:
	@if [ ! -d ".git" ]; then echo "Error: Current directory is not a git repository."; exit 1; fi
	git checkout --orphan clean_start
	git rm -rf [0-9]*-[0-9]* 2>/dev/null || true
	rm -rf [0-9]*-[0-9]* .cache
	printf "# Canadian Parliamentary Bills Database\n\nThis repository contains a versioned history of Canadian legislative bills and text revisions.\n\n## Supported Sessions\n\n| Session | Link | Status | Last Updated |\n| --- | --- | --- | --- |\n" > README.md
	git rm -r --cached .cache 2>/dev/null || true
	git add .github .gitignore Makefile LICENSE.md README.md 2>/dev/null || true
	git commit -m "Initial commit: Repository configuration and technical setup"
	git branch -M main
	@echo "Repository history successfully reset to single clean initial commit."



