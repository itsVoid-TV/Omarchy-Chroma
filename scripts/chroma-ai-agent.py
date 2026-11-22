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


def call_openai(base_url, messages):
    url = base_url.rstrip("/") + "/v1/chat/completions"
    data = {"model": "local", "messages": messages}
    req = urllib.request.Request(
        url, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        obj = json.load(r)
    return obj["choices"][0]["message"]["content"]


def call_ollama(messages):
    url = "http://127.0.0.1:11434/api/chat"
    data = {"model": "llama3.2", "messages": messages, "stream": False}
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
    for c in commands:
        print(f"$ {c}")
        subprocess.run(c, shell=True)


def main():
    if len(sys.argv) < 2:
        print("Usage: chroma ai \"your styling request\"")
        sys.exit(2)
    request = " ".join(sys.argv[1:])

    runtime = detect_runtime()
    if not runtime:
        print("No local AI runtime found.\n")
        print("Install OpenCode (no account required):")
        print("  curl -fsSL https://opencode.ai/install | bash")
        sys.exit(1)

    print(f"Omarchy Chroma AI Stylist — runtime: {runtime}")
    print(f"Request: {request}\n")

    # Delegate to CLI runtimes that handle their own interaction.
    if runtime in ("opencode", "antigravity", "codex", "claude"):
        system = load_prompt()
        full = system + "\n\nUser request: " + request
        cmd = [runtime, "run", "--auto", full] if runtime == "opencode" else [runtime, full]
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
        if base_url == "http://127.0.0.1:11434":
            reply = call_ollama(messages)
        else:
            reply = call_openai(base_url, messages)
        print("\n" + reply + "\n")
        messages.append({"role": "assistant", "content": reply})

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

        user_input = input("You (or 'done' to finish): ").strip()
        if user_input.lower() in ("done", "exit", "quit", ""):
            break
        messages.append({"role": "user", "content": user_input})


if __name__ == "__main__":
    main()
