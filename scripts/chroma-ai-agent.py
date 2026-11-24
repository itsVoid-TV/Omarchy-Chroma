#!/usr/bin/env python3
"""Omarchy Chroma AI Stylist agent (v2).

Interactive loop: plan -> ask -> dry-run -> apply, using a local OpenAI-compatible
endpoint (ollama, LM Studio, or any local server). For opencode/codex/claude/antigravity
runtimes, falls back to delegation through the runtime CLI.
"""
import json
import os
import subprocess
import sys
import urllib.request
import shlex

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROMPT_FILE = os.path.join(SCRIPT_DIR, "ai-stylist-prompt.md")
DETECT = os.path.join(SCRIPT_DIR, "detect-local-ai.sh")


def detect_runtime():
    try:
        out = subprocess.check_output([DETECT], stderr=subprocess.DEVNULL, text=True)
        return out.strip()
    except subprocess.CalledProcessError:
        return ""


def load_prompt():
    try:
        with open(PROMPT_FILE) as f:
            return f.read()
    except FileNotFoundError:
        return "You are the Omarchy Chroma AI Stylist."


def call_openai(base_url, messages, model="local"):
    url = base_url.rstrip("/") + "/v1/chat/completions"
    data = {"model": model, "messages": messages, "temperature": 0.2}
    req = urllib.request.Request(
        url, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        obj = json.load(r)
    return obj["choices"][0]["message"]["content"]


def pick_ollama_model():
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as r:
            obj = json.load(r)
        models = [m.get("name") for m in obj.get("models", []) if m.get("name")]
        # Prefer coder models
        for pref in ["qwen2.5-coder", "deepseek-coder", "codellama", "llama3.2", "nemotron"]:
            for m in models:
                if pref in m:
                    return m
        return models[0] if models else None
    except Exception:
        return None


def pick_lmstudio_model():
    try:
        with urllib.request.urlopen("http://127.0.0.1:1234/v1/models", timeout=5) as r:
            obj = json.load(r)
        models = [m.get("id") for m in obj.get("data", []) if m.get("id")]
        return models[0] if models else None
    except Exception:
        return None


def call_ollama(messages, model):
    url = "http://127.0.0.1:11434/api/chat"
    data = {"model": model, "messages": messages, "stream": False, "options": {"temperature": 0.2}}
    req = urllib.request.Request(
        url, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        obj = json.load(r)
    return obj["message"]["content"]


def call_lmstudio(messages, model):
    url = "http://127.0.0.1:1234/v1/chat/completions"
    data = {"model": model, "messages": messages, "temperature": 0.2}
    req = urllib.request.Request(
        url, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        obj = json.load(r)
    return obj["choices"][0]["message"]["content"]


def run_commands(commands):
    print("\n--- Proposed commands (dry run) ---")
    for c in commands:
        print("  " + c)
    ans = input("\nApply these? [y/N] ").strip().lower()
    if ans != "y":
        print("Skipped.")
        return
    for c in commands:
        print(f"$ {c}")
        subprocess.run(c, shell=True)


def extract_commands(text):
    """Extract commands from a COMMANDS: block in the response."""
    commands = []
    in_cmds = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("COMMANDS:"):
            in_cmds = True
            continue
        if in_cmds:
            if not stripped:
                in_cmds = False
                continue
            if stripped.startswith("- "):
                commands.append(stripped[2:].strip())
            else:
                in_cmds = False
    return commands


def main():
    if len(sys.argv) < 2:
        print("Usage: chroma ai \"your styling request\"")
        print("       chroma ai --interactive   # start interactive chat")
        sys.exit(2)

    interactive = False
    if sys.argv[1] == "--interactive":
        interactive = True
        if len(sys.argv) < 3:
            print("Usage: chroma ai --interactive \"initial request\"")
            sys.exit(2)
        request = " ".join(sys.argv[2:])
    else:
        request = " ".join(sys.argv[1:])

    runtime = detect_runtime()
    if not runtime:
        print("No local AI runtime found.\n")
        print("Install OpenCode (no account required, fully local):")
        print("  curl -fsSL https://opencode.ai/install | bash")
        print("\nOr install Ollama + a coder model:")
        print("  curl -fsSL https://ollama.com/install.sh | sh")
        print("  ollama pull qwen2.5-coder:7b")
        sys.exit(1)

    print(f"Omarchy Chroma AI Stylist — runtime: {runtime}")
    print(f"Request: {request}\n")

    # Delegate to CLI runtimes that handle their own interaction
    if runtime in ("opencode", "antigravity", "codex", "claude"):
        system = load_prompt()
        full = system + "\n\nUser request: " + request
        if runtime == "opencode":
            # Resolve a LOCAL provider/model; do not assume OpenCode is local.
            try:
                models_out = subprocess.check_output(
                    ["opencode", "models"], stderr=subprocess.DEVNULL, text=True
                )
            except Exception:
                models_out = ""
            local_model = None
            for line in models_out.splitlines():
                line = line.strip()
                if any(k in line.lower() for k in ("ollama", "lmstudio", "local", "localhost")):
                    local_model = line
                    break
            if not local_model:
                print("OpenCode has no local provider configured.")
                print("Install Ollama or configure a local provider, then retry.")
                print("  curl -fsSL https://ollama.com/install.sh | sh")
                sys.exit(1)
            cmd = ["opencode", "run", "--auto", "--model", local_model, full]
        else:
            cmd = [runtime, full]
        subprocess.run(cmd)
        return

    # Oh My Posh - delegate for prompt/theme generation
    if runtime == "ohmyposh":
        system = load_prompt()
        full = system + "\n\nUser request: " + request
        # omp doesn't have a direct chat mode, so we use openai-compatible path
        # but we can suggest omp commands
        print("Oh My Posh detected. For prompt/theme generation, I'll use the local LLM path.")
        print("You can also run 'omp config' or 'omp theme' directly.\n")

    # OpenAI-compatible path (Ollama, LM Studio, generic)
    base_url = None
    api_type = "openai"  # "openai", "ollama", "lmstudio"

    if runtime == "ollama":
        base_url = "http://127.0.0.1:11434"
        api_type = "ollama"
    elif runtime == "lmstudio":
        base_url = "http://127.0.0.1:1234"
        api_type = "lmstudio"
    elif runtime.startswith("openai-compatible:"):
        base_url = runtime.split(":", 1)[1]
        api_type = "openai"
    else:
        print(f"Unsupported runtime: {runtime}")
        sys.exit(1)

    system = load_prompt()
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": request}
    ]

    while True:
        try:
            if api_type == "ollama":
                model = pick_ollama_model()
                if not model:
                    print("No Ollama model available. Pull one first: ollama pull qwen2.5-coder:7b")
                    sys.exit(1)
                reply = call_ollama(messages, model)
            elif api_type == "lmstudio":
                model = pick_lmstudio_model()
                if not model:
                    print("No LM Studio model loaded. Load a model in LM Studio first.")
                    sys.exit(1)
                reply = call_lmstudio(messages, model)
            else:
                # Generic OpenAI-compatible
                try:
                    with urllib.request.urlopen(base_url.rstrip("/") + "/v1/models", timeout=5) as r:
                        obj = json.load(r)
                    model = obj["data"][0]["id"] if obj.get("data") else "local"
                except Exception:
                    model = "local"
                reply = call_openai(base_url, messages, model)
        except urllib.error.HTTPError as e:
            print(f"API error ({e.code}): {e.reason}")
            if e.code == 404:
                print("Check that the endpoint is correct and the model exists.")
            sys.exit(1)
        except urllib.error.URLError as e:
            print(f"Connection error: {e.reason}")
            print(f"Is the server running at {base_url}?")
            sys.exit(1)
        except Exception as e:
            print(f"Unexpected error: {e}")
            sys.exit(1)

        print("\n" + reply + "\n")
        messages.append({"role": "assistant", "content": reply})

        # Extract proposed commands if present
        commands = extract_commands(reply)
        if commands:
            run_commands(commands)

        if not interactive:
            break

        user_input = input("You (or 'done' to finish): ").strip()
        if user_input.lower() in ("done", "exit", "quit", ""):
            break
        messages.append({"role": "user", "content": user_input})


if __name__ == "__main__":
    main()