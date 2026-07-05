#!/usr/bin/env zsh
# =============================================================================
#  ds-helpers.sh  —  DeepSeek ↔ Claude Code direct integration (no proxy)
#
#  Source from ~/.zshrc:
#    source /Users/jamshidbekboynazarov/MySpace/deepseek/ds-helpers.sh
#
#  DeepSeek's Anthropic-compatible API is used directly — no proxy server.
#  Claude Code talks to api.deepseek.com/anthropic as if it were Anthropic.
#
#  Commands:
#    ds  [flash|pro]   — launch Claude Code via DeepSeek (normal)
#    dsp [flash|pro]   — launch Claude Code via DeepSeek (skip permissions)
#    dsmodel [flash|pro] — show or persistently set the default model
#    dsbalance         — show remaining DeepSeek API credit balance
#    dsdoctor          — diagnose connectivity & config
#    ds -h / --help    — help screen
#
#  To use real Anthropic Claude models, just run: claude   (no ds prefix)
# =============================================================================

_DS_API_KEY="sk-9806345efdc44dbab58ef02f4361022e"
_DS_BASE_URL="https://api.deepseek.com/anthropic"
_DS_CONFIG_FILE="$HOME/.ds_config"

# ---------------------------------------------------------------------------
# Internal: load persisted config (default model)
# ---------------------------------------------------------------------------
_ds_load_config() {
  if [[ -f "$_DS_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$_DS_CONFIG_FILE"
  fi
  # Fallback if not set by config
  _DS_DEFAULT_MODEL="${_DS_DEFAULT_MODEL:-pro}"
}

# Load config on source
_ds_load_config

# ---------------------------------------------------------------------------
# Internal: resolve model shorthand → full API model name
# ---------------------------------------------------------------------------
_ds_resolve_model() {
  local arg="${1:-$_DS_DEFAULT_MODEL}"
  case "$arg" in
    flash) echo "deepseek-v4-flash" ;;
    pro)   echo "deepseek-v4-pro[1m]" ;;
    *)
      echo "❌ Unknown model '$arg'. Use: flash | pro" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Internal: help screen
# ---------------------------------------------------------------------------
_ds_help() {
  echo ""
  echo "  ██████╗ ███████╗"
  echo "  ██╔══██╗██╔════╝   DeepSeek × Claude Code"
  echo "  ██║  ██║███████╗   Direct Anthropic-compatible integration"
  echo "  ██║  ██║╚════██║   api.deepseek.com/anthropic"
  echo "  ██████╔╝███████║"
  echo "  ╚═════╝ ╚══════╝"
  echo ""
  echo "  USAGE"
  echo "  ─────────────────────────────────────────────────────────────"
  echo "  ds                  Launch Claude Code via DeepSeek (pro 1M)"
  echo "  ds pro              Same — DeepSeek V4 Pro  [1M ctx, smarter]"
  echo "  ds flash            Same — DeepSeek V4 Flash [fast, cheap]  "
  echo ""
  echo "  dsp                 Same as ds  + skip ALL permission prompts"
  echo "  dsp pro             DeepSeek V4 Pro  + skip permissions      "
  echo "  dsp flash           DeepSeek V4 Flash + skip permissions     "
  echo ""
  echo "  dsmodel             Show current default model               "
  echo "  dsmodel flash       Persistently switch default to flash     "
  echo "  dsmodel pro         Persistently switch default to pro       "
  echo ""
  echo "  dsbalance           Show remaining DeepSeek API credit       "
  echo ""
  echo "  dsdoctor            Diagnose config, API key & connectivity  "
  echo ""
  echo "  ds -h / ds --help   Show this help screen                    "
  echo "  dsp -h              Same help screen                         "
  echo ""
  echo "  claude              Normal Claude Code (real Anthropic creds) "
  echo ""
  echo "  MODELS"
  echo "  ─────────────────────────────────────────────────────────────"
  echo "  flash  →  deepseek-v4-flash       Fast & cheap, great for    "
  echo "                                    subagents & quick tasks    "
  echo "  pro    →  deepseek-v4-pro[1m]     Full power, 1M token ctx   "
  echo "                                    (default for bare ds/dsp)  "
  echo ""
  echo "  TIPS"
  echo "  ─────────────────────────────────────────────────────────────"
  echo "  • Subagent / Haiku tier always uses deepseek-v4-flash        "
  echo "  • Pro tier always has reasoning effort set to max            "
  echo "  • plain 'claude' is untouched — uses your Anthropic key      "
  echo "  • API top-up: https://platform.deepseek.com                  "
  echo ""
}

# ---------------------------------------------------------------------------
# Internal: core launcher
# ---------------------------------------------------------------------------
_ds_launch() {
  local skip_perms="${1:-no}"
  local model_arg="${2:-}"

  # Resolve model
  local main_model
  main_model=$(_ds_resolve_model "$model_arg") || return 1

  # Haiku/subagent tier always uses flash (fast, cheap)
  local fast_model="deepseek-v4-flash"

  # Print launch banner
  local label="🤖 DeepSeek → Claude Code"
  [[ "$skip_perms" == "yes" ]] && label="⚡ DeepSeek → Claude Code (permissions skipped)"
  echo "$label"
  echo "   Model:    $main_model"
  echo "   Subagent: $fast_model"
  echo "   Endpoint: $_DS_BASE_URL"
  echo ""

  # Build claude args
  local claude_args=()
  [[ "$skip_perms" == "yes" ]] && claude_args+=("--dangerously-skip-permissions")

  # Launch claude with DeepSeek env vars — real Anthropic vars are NOT exported
  # globally so plain `claude` still works with actual Anthropic credentials.
  ANTHROPIC_BASE_URL="$_DS_BASE_URL" \
  ANTHROPIC_AUTH_TOKEN="$_DS_API_KEY" \
  ANTHROPIC_MODEL="${main_model}" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="${main_model}" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="${main_model}" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="${fast_model}" \
  CLAUDE_CODE_SUBAGENT_MODEL="${fast_model}" \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW="190000" \
  claude "${claude_args[@]}"
}

# ---------------------------------------------------------------------------
# Public commands
# ---------------------------------------------------------------------------

# ds [flash|pro]  — DeepSeek-backed Claude, normal permissions
ds() {
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { _ds_help; return 0; }
  _ds_launch "no" "${1:-}"
}

# dsp [flash|pro]  — DeepSeek-backed Claude, SKIP permissions
dsp() {
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { _ds_help; return 0; }
  _ds_launch "yes" "${1:-}"
}

# dsmodel [flash|pro]  — show or persistently change the default model
dsmodel() {
  local arg="${1:-}"

  if [[ -z "$arg" ]]; then
    # No argument — just show current state
    local resolved
    resolved=$(_ds_resolve_model "$_DS_DEFAULT_MODEL")
    echo "🔍 Default model : $_DS_DEFAULT_MODEL  →  $resolved"
    echo ""
    echo "   ds flash    →  deepseek-v4-flash          (fast, cheap)"
    echo "   ds pro      →  deepseek-v4-pro[1m]        (smart, 1M context)"
    echo "   dsp flash   →  deepseek-v4-flash  + skip permissions"
    echo "   dsp pro     →  deepseek-v4-pro[1m] + skip permissions"
    echo ""
    echo "   Run 'dsmodel flash' or 'dsmodel pro' to change the default."
    echo "   Plain 'claude' still uses your normal Anthropic credentials."
    return 0
  fi

  # Validate the arg
  _ds_resolve_model "$arg" > /dev/null || return 1

  # Persist to config file
  echo "_DS_DEFAULT_MODEL=\"$arg\"" > "$_DS_CONFIG_FILE"

  # Apply in current shell immediately
  _DS_DEFAULT_MODEL="$arg"

  local resolved
  resolved=$(_ds_resolve_model "$arg")
  echo "✅ Default model saved: $arg  →  $resolved"
  echo "   Takes effect immediately — no need to reload shell."
}

# dsbalance  — show remaining DeepSeek API credit balance
dsbalance() {
  echo "💳 Checking DeepSeek balance..."

  local response
  response=$(curl -sf \
    -H "Authorization: Bearer $_DS_API_KEY" \
    "https://api.deepseek.com/user/balance" 2>&1)

  local curl_exit=$?
  if [[ $curl_exit -ne 0 ]]; then
    echo "❌ Could not reach api.deepseek.com (network error)"
    return 1
  fi

  # Parse with python if available (cleaner), fallback to grep
  if command -v python3 &>/dev/null; then
    python3 - "$response" <<'PYEOF'
import sys, json
try:
    data = json.loads(sys.argv[1])
    if not data.get("is_available"):
        print("❌  Account not available or API key invalid")
        sys.exit(1)
    for b in data.get("balance_infos", []):
        currency = b.get("currency", "?")
        total    = b.get("total_balance", "?")
        granted  = b.get("granted_balance", "?")
        topped   = b.get("topped_up_balance", "?")
        print(f"   Currency        : {currency}")
        print(f"   Total balance   : {total}")
        print(f"   Granted (free)  : {granted}")
        print(f"   Topped up       : {topped}")
except Exception as e:
    print(f"⚠️  Could not parse response: {e}")
    print(f"   Raw: {sys.argv[1][:300]}")
PYEOF
  else
    # Fallback: raw output
    echo "$response"
  fi
}

# dsdoctor  — diagnose the full setup
dsdoctor() {
  local ok=0
  local fail=0

  _check() {
    local label="$1"
    local result="$2"  # "pass" or "fail"
    local detail="${3:-}"
    if [[ "$result" == "pass" ]]; then
      echo "  ✅  $label${detail:+  ($detail)}"
      (( ok++ ))
    else
      echo "  ❌  $label${detail:+  — $detail}"
      (( fail++ ))
    fi
  }

  echo ""
  echo "  🩺  DS Doctor — diagnosing your DeepSeek setup"
  echo "  ─────────────────────────────────────────────────────────────"
  echo ""

  # 1. claude CLI installed?
  if command -v claude &>/dev/null; then
    local cv
    cv=$(claude --version 2>/dev/null | head -1)
    _check "Claude Code installed" pass "$cv"
  else
    _check "Claude Code installed" fail "run: npm install -g @anthropic-ai/claude-code"
  fi

  # 2. API key present?
  if [[ -n "$_DS_API_KEY" && "$_DS_API_KEY" != "YOUR_KEY_HERE" ]]; then
    local masked="${_DS_API_KEY:0:8}…${_DS_API_KEY: -4}"
    _check "API key configured" pass "$masked"
  else
    _check "API key configured" fail "set _DS_API_KEY in ds-helpers.sh"
  fi

  # 3. Network reachability to api.deepseek.com
  local http_code
  http_code=$(curl -sf -o /dev/null -w "%{http_code}" \
    --max-time 6 \
    -H "Authorization: Bearer $_DS_API_KEY" \
    "https://api.deepseek.com/user/balance" 2>/dev/null)
  local curl_exit=$?

  if [[ $curl_exit -eq 0 || "$http_code" =~ ^[234] ]]; then
    _check "Network → api.deepseek.com" pass "HTTP $http_code"
  elif [[ "$http_code" == "402" ]]; then
    _check "Network → api.deepseek.com" pass "reachable (402 = needs top-up)"
  elif [[ "$http_code" == "401" ]]; then
    _check "Network → api.deepseek.com" fail "HTTP 401 — API key rejected"
  else
    _check "Network → api.deepseek.com" fail "unreachable (exit=$curl_exit http=$http_code)"
  fi

  # 4. Config file
  if [[ -f "$_DS_CONFIG_FILE" ]]; then
    local saved_model
    saved_model=$(grep '_DS_DEFAULT_MODEL' "$_DS_CONFIG_FILE" 2>/dev/null | head -1)
    _check "Config file (~/.ds_config)" pass "$saved_model"
  else
    _check "Config file (~/.ds_config)" pass "using built-in default ($_DS_DEFAULT_MODEL)"
  fi

  # 5. Default model resolvable?
  local resolved
  if resolved=$(_ds_resolve_model "$_DS_DEFAULT_MODEL" 2>/dev/null); then
    _check "Default model valid" pass "$_DS_DEFAULT_MODEL → $resolved"
  else
    _check "Default model valid" fail "unknown model '$_DS_DEFAULT_MODEL'"
  fi

  # 6. Tab completion registered?
  if (( ${+functions[_ds_completions]} )); then
    _check "Tab completion" pass "registered"
  else
    _check "Tab completion" fail "not loaded (re-source ~/.zshrc)"
  fi

  echo ""
  echo "  ─────────────────────────────────────────────────────────────"
  if [[ $fail -eq 0 ]]; then
    echo "  🎉  All $ok checks passed — ready to go!"
  else
    echo "  ⚠️   $ok passed, $fail failed — fix the items above."
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# Tab completion
# ---------------------------------------------------------------------------
_ds_completions() {
  local -a subcmds
  subcmds=(
    'flash:Use deepseek-v4-flash (fast, cheap)'
    'pro:Use deepseek-v4-pro\[1m\] (smart, 1M context)'
    '-h:Show help'
    '--help:Show help'
  )
  _describe 'model' subcmds
}

_ds_model_completions() {
  local -a subcmds
  subcmds=(
    'flash:Set default to deepseek-v4-flash'
    'pro:Set default to deepseek-v4-pro\[1m\]'
  )
  _describe 'model' subcmds
}

# Register completions only when zsh compdef is available (interactive shell)
if (( ${+functions[compdef]} )); then
  compdef _ds_completions ds
  compdef _ds_completions dsp
  compdef _ds_model_completions dsmodel
fi
