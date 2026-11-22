#!/usr/bin/env python3
"""Omarchy Chroma AI Stylist agent (v2).

Interactive loop: plan -> ask -> dry-run -> apply, using a local OpenAI-compatible
endpoint (ollama or any local server). For opencode/codex/claude/antigravity runtimes,
falls back to delegation through the runtime CLI.
"""
import json
import os
import subprocess
import sys
import urllib.request

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
    data = {"model": model, "messages": messages}
    req = urllib.request.Request(
        url, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        obj = json.load(r)
    return obj["choices"][0]["message"]["content"]


def pick_ollama_model(preferred=None):
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=5) as r:
            obj = json.load(r)
        models = [m.get("name") for m in obj.get("models", []) if m.get("name")]
        if not models:
            return None
        if preferred and preferred in models:
            return preferred
        # Honour a configured model name even if the exact tag differs slightly.
        if preferred:
            for m in models:
                if m.split(":")[0] == preferred.split(":")[0]:
                    return m
        return models[0]
    except Exception:
        return None


def call_ollama(messages, model):
    url = "http://127.0.0.1:11434/api/chat"
    data = {"model": model, "messages": messages, "stream": False}
    req = urllib.request.Request(
        url, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        obj = json.load(r)
    return obj["message"]["content"]


def run_commands(commands):
    print("\n--- Proposed commands (dry run) ---")
    for c in commands:
        print("  " + c)
    ans = input("\nApply these? [y/N] ").strip().lower()
    if ans != "y":
        print("Skipped.")
        return
    script = "set -e\\n" + "\\n".join(commands)
    print("$ " + " && ".join(commands))
    proc = subprocess.run(script, shell=True, executable="/bin/bash")
    if proc.returncode != 0:
        print(f"Command batch failed (exit {proc.returncode}); later commands were not run.")


def main():
    once = "--once" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--once"]
    if not args:
        try:
            request = input("Your styling request: ").strip()
        except EOFError:
            request = ""
        if not request:
            print("Usage: chroma ai \"your styling request\"")
            sys.exit(2)
    else:
        request = " ".join(args)

    runtime = detect_runtime()
    if not runtime:
        print("No local AI runtime found.\n")
        print("Install OpenCode (no account required):")
        print("  curl -fsSL https://opencode.ai/install | bash")
        sys.exit(1)

    history_file = os.path.expanduser("~/.local/state/omarchy-chroma/ai-chat.log")
    os.makedirs(os.path.dirname(history_file), exist_ok=True)
    print(f"Omarchy Chroma AI Stylist — runtime: {runtime}")
    print(f"Request: {request}\n")

    # Delegate to CLI runtimes that handle their own interaction.
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
                if any(k in line.lower() for k in ("ollama", "lmstudio", "localai", "vllm", "llamacpp", "localhost", "127.0.0.1")):
                    local_model = line
                    break
            if not local_model:
                print("OpenCode has no local provider configured.")
                print("Install Ollama or configure a local provider, then retry.")
                print("  curl -fsSL https://ollama.com/install.sh | sh")
                sys.exit(1)
            cmd = ["opencode", "run", "--auto", "--model", local_model, full]
        elif runtime == "codex":
            # Force Codex into local-provider mode; otherwise it may use cloud.
            cmd = ["codex", "--oss", full]
        else:
            cmd = [runtime, full]
        subprocess.run(cmd)
        return

    # OpenAI-compatible path.
    base_url = None
    if runtime == "ollama":
        base_url = "http://127.0.0.1:11434"
    elif runtime.startswith("openai-compatible:"):
        base_url = runtime.split(":", 1)[1].replace("openai-compatible", "", 1).lstrip(":").rstrip("/")
        # reconstruct
        base_url = runtime[len("openai-compatible:"):]
    else:
        print(f"Unsupported runtime: {runtime}")
        sys.exit(1)

    system = load_prompt()
    messages = [{"role": "system", "content": system},
                {"role": "user", "content": request}]

    while True:
        preferred = os.environ.get("CHROMA_AI_MODEL")
        if base_url == "http://127.0.0.1:11434":
            model = pick_ollama_model(preferred)
            if not model:
                print("No Ollama model available. Pull one first: ollama pull llama3.2")
                sys.exit(1)
            reply = call_ollama(messages, model)
        else:
            # Pick an available model from the OpenAI-compatible endpoint.
            model = "local"
            try:
                with urllib.request.urlopen(base_url.rstrip("/") + "/v1/models", timeout=5) as r:
                    obj = json.load(r)
                ids = [m.get("id") for m in obj.get("data", []) if m.get("id")]
                if preferred and preferred in ids:
                    model = preferred
                elif ids:
                    model = ids[0]
            except Exception:
                if preferred:
                    model = preferred
            reply = call_openai(base_url, messages, model)
        print("\n" + reply + "\n")
        messages.append({"role": "assistant", "content": reply})
        try:
            with open(history_file, "a") as hf:
                hf.write("You: " + request + "\n")
                hf.write("Assistant: " + reply + "\n\n")
        except OSError:
            pass

        # Extract proposed commands if present.
        commands = []
        in_cmds = False
        for line in reply.splitlines():
            if line.strip().startswith("COMMANDS:"):
                in_cmds = True
                continue
            if in_cmds:
                s = line.strip()
                if not s:
                    in_cmds = False
                    continue
                if s.startswith("- "):
                    commands.append(s[2:].strip())
                else:
                    in_cmds = False
        if commands:
            run_commands(commands)

        if once:
            break
        user_input = input("You (or 'done' to finish): ").strip()
        if user_input.lower() in ("done", "exit", "quit", ""):
            break
        messages.append({"role": "user", "content": user_input})


if __name__ == "__main__":
    main()
