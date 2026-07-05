<div align="center">

# 🤖 DeepSeek CLI Proxy

**Run Claude Code with DeepSeek — free, fast, and self-hosted.**

Use the Claude Code CLI (or VS Code / JetBrains ACP) through a local Anthropic-compatible proxy backed by [DeepSeek](https://platform.deepseek.com/) and 10+ other model providers.

[![Python 3.14](https://img.shields.io/badge/python-3.14-3776ab.svg?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json&style=for-the-badge)](https://github.com/astral-sh/uv)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

</div>

---

## ✨ What It Does

This proxy sits between **Claude Code** and any AI model provider. Claude Code thinks it's talking to Anthropic — the proxy transparently forwards requests to DeepSeek (or any of the other supported providers) and streams responses back.

**Supported providers:**

| # | Provider | Free Tier | Notes |
|---|---|---|---|
| 1 | **DeepSeek** | ✅ | Recommended — cheapest |
| 2 | **NVIDIA NIM** | ✅ | Large free quota |
| 3 | **OpenRouter** | ✅ | Many free models |
| 4 | **Kimi / Moonshot** | ✅ | — |
| 5 | **Wafer** | — | Anthropic-native endpoint |
| 6 | **OpenCode Zen** | ✅ | Multi-provider gateway |
| 7 | **OpenCode Go** | — | Subscription gateway |
| 8 | **Z.ai** | ✅ | GLM models |
| 9 | **LM Studio** | ✅ | Local, no API key |
| 10 | **llama.cpp** | ✅ | Local, no API key |
| 11 | **Ollama** | ✅ | Local, no API key |

---

## 🚀 Quick Start

### 1 — Install `uv` (Python runtime manager)

**macOS / Linux:**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env   # or restart your terminal
uv self update
uv python install 3.14
```

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
uv self update
uv python install 3.14
```

---

### 2 — Install Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

> Requires Node.js ≥ 18. Install from [nodejs.org](https://nodejs.org/) if needed.

---

### 3 — Install the Proxy

```bash
uv tool install --force git+https://github.com/jamie10x/deepseekcli.git
```

This puts `fcc-server`, `fcc-claude`, and `fcc-init` on your `PATH`.

---

### 4 — Get a DeepSeek API Key

1. Sign up at [platform.deepseek.com](https://platform.deepseek.com/)
2. Go to **API Keys** → create a key
3. Copy it — you'll paste it in the next step

---

### 5 — Configure the Proxy

Create `~/.fcc/.env`:

```bash
mkdir -p ~/.fcc
cat > ~/.fcc/.env << 'EOF'
# ── Required ──────────────────────────────────────────────────────
DEEPSEEK_API_KEY="sk-your-key-here"

# ── Model Routing ─────────────────────────────────────────────────
MODEL="deepseek/deepseek-chat"
MODEL_OPUS="deepseek/deepseek-chat"
MODEL_SONNET="deepseek/deepseek-chat"
MODEL_HAIKU="deepseek/deepseek-chat"

# ── Server ────────────────────────────────────────────────────────
ANTHROPIC_AUTH_TOKEN="freecc"
FCC_OPEN_BROWSER=true
EOF
```

> **Headless servers:** set `FCC_OPEN_BROWSER=false` to skip auto-opening a browser.

---

### 6 — Start the Proxy

```bash
fcc-server
```

Expected output:

```
INFO:     Uvicorn running on http://127.0.0.1:8082
INFO:     Admin UI: http://127.0.0.1:8082/admin (local-only)
```

---

### 7 — Launch Claude Code

```bash
fcc-claude
```

`fcc-claude` reads your configured port and auth token, sets the necessary environment variables, and launches `claude` pointed at your proxy. That's it — you're coding with DeepSeek through Claude Code. 🎉

---

## 🖥️ Admin UI

Open [http://127.0.0.1:8082/admin](http://127.0.0.1:8082/admin) to:

- Swap API keys and model slugs without restarting
- Validate provider connectivity
- Configure Discord / Telegram bots
- Adjust rate limits, timeouts, and server settings

---

## 🔌 Connect Clients

### Claude Code CLI (quickest)

```bash
fcc-claude
```

### VS Code Extension

Open **Settings → Edit in settings.json** and add:

```json
"claudeCode.environmentVariables": [
  { "name": "ANTHROPIC_BASE_URL", "value": "http://localhost:8082" },
  { "name": "ANTHROPIC_AUTH_TOKEN", "value": "freecc" },
  { "name": "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY", "value": "1" },
  { "name": "CLAUDE_CODE_AUTO_COMPACT_WINDOW", "value": "190000" }
]
```

### JetBrains ACP

Edit `~/.jetbrains/acp.json` (Linux/macOS) or `%APPDATA%\JetBrains\acp-agents\installed.json` (Windows):

```json
"env": {
  "ANTHROPIC_BASE_URL": "http://localhost:8082",
  "ANTHROPIC_AUTH_TOKEN": "freecc",
  "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
  "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "190000"
}
```

### Manual (any terminal)

```bash
export ANTHROPIC_BASE_URL=http://localhost:8082
export ANTHROPIC_AUTH_TOKEN=freecc
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
claude
```

---

## 🌐 Server / Remote Installation

### Run in background with `tmux`

```bash
tmux new-session -d -s fcc 'fcc-server'
# Attach later:
tmux attach -t fcc
```

### Run as a `systemd` service (Linux)

```bash
sudo tee /etc/systemd/system/fcc-server.service > /dev/null << EOF
[Unit]
Description=DeepSeek Claude Code Proxy
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$HOME/.local/bin/fcc-server
Restart=on-failure
RestartSec=5
EnvironmentFile=$HOME/.fcc/.env

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now fcc-server
sudo systemctl status fcc-server
```

### Access Admin UI from your laptop (SSH tunnel)

```bash
ssh -L 8082:localhost:8082 user@your-server-ip
# Then open http://localhost:8082/admin locally
```

---

## ⚡ Model Routing

You can route different Claude "tiers" to different providers:

```ini
MODEL_OPUS="deepseek/deepseek-chat"
MODEL_SONNET="open_router/deepseek/deepseek-r1-0528:free"
MODEL_HAIKU="nvidia_nim/nvidia/nemotron-3-super-120b-a12b"
MODEL="deepseek/deepseek-chat"       # fallback for everything else
```

Leave a tier blank to inherit `MODEL`.

### Available Model Slugs

| Provider | Slug Format | Example |
|---|---|---|
| DeepSeek | `deepseek/<model>` | `deepseek/deepseek-chat` |
| NVIDIA NIM | `nvidia_nim/<org>/<model>` | `nvidia_nim/nvidia/nemotron-3-super-120b-a12b` |
| OpenRouter | `open_router/<org>/<model>` | `open_router/deepseek/deepseek-r1-0528:free` |
| Kimi | `kimi/<model>` | `kimi/kimi-k2.5` |
| Wafer | `wafer/<model>` | `wafer/DeepSeek-V4-Pro` |
| OpenCode Zen | `opencode/<model>` | `opencode/deepseek-v4-flash-free` |
| OpenCode Go | `opencode_go/<model>` | `opencode_go/minimax-m2.7` |
| Z.ai | `zai/<model>` | `zai/glm-5.1` |
| LM Studio | `lmstudio/<model-id>` | `lmstudio/deepseek-r1` |
| llama.cpp | `llamacpp/<model>` | `llamacpp/deepseek-r1` |
| Ollama | `ollama/<model>` | `ollama/llama3.1:8b` |

---

## ⚙️ Environment Variables Reference

| Variable | Default | Description |
|---|---|---|
| `DEEPSEEK_API_KEY` | — | **Required** for DeepSeek |
| `NVIDIA_NIM_API_KEY` | — | NVIDIA NIM key |
| `OPENROUTER_API_KEY` | — | OpenRouter key |
| `MODEL` | `nvidia_nim/...` | Fallback model |
| `MODEL_OPUS` | _(inherits MODEL)_ | Opus-tier model |
| `MODEL_SONNET` | _(inherits MODEL)_ | Sonnet-tier model |
| `MODEL_HAIKU` | _(inherits MODEL)_ | Haiku-tier model |
| `PORT` | `8082` | Proxy listen port |
| `HOST` | `127.0.0.1` | Bind address |
| `ANTHROPIC_AUTH_TOKEN` | `freecc` | Bearer token for clients |
| `FCC_OPEN_BROWSER` | `true` | Auto-open Admin UI on start |
| `ENABLE_MODEL_THINKING` | `true` | Enable reasoning blocks |
| `HTTP_READ_TIMEOUT` | `300` | Provider response timeout (s) |

Full reference: [`.env.example`](.env.example)

---

## 🔄 Updating

```bash
uv tool install --force git+https://github.com/jamie10x/deepseekcli.git
# Then restart the server
sudo systemctl restart fcc-server   # systemd
# OR
pkill -f fcc-server && fcc-server   # manual
```

---

## 🛠️ Development (Run from Source)

```bash
git clone https://github.com/jamie10x/deepseekcli.git
cd deepseekcli
cp .env.example .env
# Edit .env: set DEEPSEEK_API_KEY and MODEL

# Run directly
uv run uvicorn server:app --host 127.0.0.1 --port 8082
```

### CI checks (run before every commit)

```bash
uv run ruff format
uv run ruff check
uv run ty check
uv run pytest
```

### Project structure

```
deepseekcli/
├── server.py          # ASGI entry point
├── api/               # FastAPI routes, admin UI, model routing
├── core/              # Shared Anthropic protocol helpers, SSE utilities
├── providers/         # Provider transports (DeepSeek, NIM, OpenRouter, …)
├── messaging/         # Discord / Telegram adapters and voice transcription
├── cli/               # Package entry points (fcc-server, fcc-claude, …)
├── config/            # Settings, provider catalog, logging
└── tests/             # Unit and contract tests
```

---

## 🔧 Troubleshooting

| Symptom | Fix |
|---|---|
| `command not found: fcc-server` | Add `~/.local/bin` to PATH: `export PATH="$HOME/.local/bin:$PATH"` |
| Port 8082 already in use | Set `PORT=8083` in `~/.fcc/.env` |
| 401 Unauthorized | Check `ANTHROPIC_AUTH_TOKEN` matches on server and client |
| Provider returns HTTP 400 | Check API key is valid; click **Validate** in Admin UI |
| Admin UI unreachable from laptop | Use SSH tunnel: `ssh -L 8082:localhost:8082 user@server` |
| No output / silent failure | Check logs: `journalctl -fu fcc-server` or `cat ~/fcc-server.log` |

---

## 📄 License

MIT — see [LICENSE](LICENSE).
