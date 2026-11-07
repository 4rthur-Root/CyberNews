.PHONY: help install run clean build-desktop

# Default
help:
	@echo "Available commands:"
	@echo "  make install        - Install dependencies and create venv via uv"
	@echo "  make run            - Run the Flet app locally with Hot-Reload"
	@echo "  make clean          - Remove virtual environments and temporary build artifacts"
	@echo "  make build-desktop  - Package the app into a standalone desktop executable"

# 1. Install all locked dependencies
install:
	uv sync

# 2. Start the application with Hot Reload
run:
	uv run flet run src/main.py

# 3. Wipe development noise
clean:
	rm -rf .venv/ .uv/ build/ dist/ __pycache__ src/**/__pycache__

# 4. Compiles app natively to host platform OS (Linux/Mac/Windows executable)
build-desktop:
	uv run flet build