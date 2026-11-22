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

# OpenAI-compatible local endpoints: require a valid models response, not just any 2xx.
if curl -fsS --max-time 2 "http://127.0.0.1:11434/api/tags" 2>/dev/null | grep '"models"' >/dev/null; then
  printf 'openai-compatible:http://127.0.0.1:11434\n'
  exit 0
fi

if curl -fsS --max-time 2 "http://127.0.0.1:8080/v1/models" 2>/dev/null | grep '"data"' >/dev/null; then
  printf 'openai-compatible:http://127.0.0.1:8080\n'
  exit 0
fi

exit 1
