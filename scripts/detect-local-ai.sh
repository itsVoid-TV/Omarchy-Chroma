#!/usr/bin/env bash
# Detect a locally available AI runtime for the Omarchy Chroma Stylist.
# Prints the first available runtime on stdout and exits 0, or exits 1 if none.
# Output format: runtime[:extra_info]
# Examples: opencode, codex, claude, ollama, lmstudio, antigravity, openai-compatible:http://127.0.0.1:11434
set -euo pipefail

# CLI runtimes that handle their own interaction
for candidate in opencode codex claude antigravity; do
  if command -v "$candidate" >/dev/null 2>&1; then
    printf '%s\n' "$candidate"
    exit 0
  fi
done

# Oh My Posh (for prompt/theme generation)
if command -v omp >/dev/null 2>&1; then
  printf 'ohmyposh\n'
  exit 0
done

# Ollama - check for running server and at least one model
if command -v ollama >/dev/null 2>&1; then
  if curl -fsS --max-time 2 "http://127.0.0.1:11434/api/tags" 2>/dev/null | grep -q '"models"'; then
    printf 'ollama\n'
    exit 0
  fi
fi

# LM Studio - check local API
if curl -fsS --max-time 2 "http://127.0.0.1:1234/v1/models" 2>/dev/null | grep -q '"data"'; then
  printf 'lmstudio\n'
  exit 0
fi

# Generic OpenAI-compatible endpoints (Ollama API, LM Studio, local vLLM, etc.)
if curl -fsS --max-time 2 "http://127.0.0.1:11434/api/tags" 2>/dev/null | grep -q '"models"'; then
  printf 'openai-compatible:http://127.0.0.1:11434\n'
  exit 0
fi

if curl -fsS --max-time 2 "http://127.0.0.1:8080/v1/models" 2>/dev/null | grep -q '"data"'; then
  printf 'openai-compatible:http://127.0.0.1:8080\n'
  exit 0
fi

if curl -fsS --max-time 2 "http://127.0.0.1:1234/v1/models" 2>/dev/null | grep -q '"data"'; then
  printf 'openai-compatible:http://127.0.0.1:1234\n'
  exit 0
fi

exit 1