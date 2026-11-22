#!/usr/bin/env bash
# Detect a locally available AI runtime for the Omarchy Chroma AI Stylist.
# Prints the first available runtime on stdout and exits 0, or exits 1 if none.
set -euo pipefail

for candidate in opencode antigravity codex claude ollama llama-cli; do
  if command -v "$candidate" >/dev/null 2>&1; then
    printf '%s\n' "$candidate"
    exit 0
  fi
done

# OpenAI-compatible local endpoints (best-effort probe).
for url in "http://127.0.0.1:11434" "http://127.0.0.1:8080"; do
  if curl -fsS --max-time 1 "$url" >/dev/null 2>&1; then
    printf 'openai-compatible:%s\n' "$url"
    exit 0
  fi
done

exit 1
