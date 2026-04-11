#!/bin/sh
# ================================================
# PFE IoT Security TT — Vault Init + Unseal + PKI
# Runs as a one-shot container after vault is healthy
# Outputs stored in /vault/init/ (named volume)
# ================================================
set -e

VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
INIT_DIR="/vault/init"
INIT_FILE="$INIT_DIR/init-output.json"

log() { echo "[vault-init] $1"; }

mkdir -p "$INIT_DIR"

# ----------------------------------------
# Wait for Vault API to be reachable
# ----------------------------------------
log "Waiting for Vault at $VAULT_ADDR ..."
for i in $(seq 1 30); do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" || true)
  # 200 = initialized+unsealed, 429 = standby, 501 = not initialized, 503 = sealed
  if [ "$status_code" = "200" ] || [ "$status_code" = "429" ] || \
     [ "$status_code" = "501" ] || [ "$status_code" = "503" ]; then
    log "Vault is reachable (HTTP $status_code)"
    break
  fi
  log "  attempt $i — HTTP $status_code, retrying..."
  sleep 3
done

# ----------------------------------------
# Check initialized state
# ----------------------------------------
INITIALIZED=$(curl -s "$VAULT_ADDR/v1/sys/init" | grep -o '"initialized":[^,}]*' | cut -d: -f2 | tr -d ' ')
log "Vault initialized: $INITIALIZED"

if [ "$INITIALIZED" = "false" ]; then
  log "Initializing Vault (5 shares, threshold 3)..."
  curl -s -X PUT \
    -H "Content-Type: application/json" \
    --data '{"secret_shares":5,"secret_threshold":3}' \
    "$VAULT_ADDR/v1/sys/init" \
    > "$INIT_FILE"

  if grep -q '"root_token"' "$INIT_FILE"; then
    log "✅ Vault initialized. Credentials saved to $INIT_FILE"
  else
    log "❌ Initialization failed. Response:"
    cat "$INIT_FILE"
    exit 1
  fi
else
  log "Vault already initialized — skipping init."
fi

# ----------------------------------------
# Extract unseal keys and root token
# ----------------------------------------
if [ ! -f "$INIT_FILE" ]; then
  log "❌ $INIT_FILE not found. Cannot unseal."
  exit 1
fi

KEY1=$(grep -o '"keys_base64":\[.*\]' "$INIT_FILE" | grep -oP '(?<=\[")[^"]+' | sed -n '1p' || \
       cat "$INIT_FILE" | tr ',' '\n' | grep '"keys_base64"' -A5 | grep '"' | head -1 | tr -d '" ')
KEY2=$(cat "$INIT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['keys_base64'][1])" 2>/dev/null || true)
KEY3=$(cat "$INIT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['keys_base64'][2])" 2>/dev/null || true)
ROOT_TOKEN=$(cat "$INIT_FILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['root_token'])" 2>/dev/null || true)

# ----------------------------------------
# Check sealed state
# ----------------------------------------
SEALED=$(curl -s "$VAULT_ADDR/v1/sys/health" | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' ')
log "Vault sealed: $SEALED"

if [ "$SEALED" = "true" ]; then
  log "Unsealing Vault..."

  if [ -z "$KEY1" ] || [ -z "$KEY2" ] || [ -z "$KEY3" ]; then
    log "❌ Could not extract unseal keys from $INIT_FILE"
    exit 1
  fi

  for KEY in "$KEY1" "$KEY2" "$KEY3"; do
    curl -s -X PUT \
      -H "Content-Type: application/json" \
      --data "{\"key\":\"$KEY\"}" \
      "$VAULT_ADDR/v1/sys/unseal" \
      | grep -o '"sealed":[^,}]*'
  done

  # Verify unsealed
  SEALED_AFTER=$(curl -s "$VAULT_ADDR/v1/sys/health" | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' ')
  if [ "$SEALED_AFTER" = "false" ]; then
    log "✅ Vault is unsealed."
  else
    log "⚠️  Vault may still be sealed — check manually."
  fi
else
  log "Vault already unsealed — skipping unseal."
fi

# ----------------------------------------
# Save root_token to a dedicated file for scripts
# ----------------------------------------
if [ -n "$ROOT_TOKEN" ]; then
  printf "VAULT_ROOT_TOKEN=%s\n" "$ROOT_TOKEN" > "$INIT_DIR/root_token.env"
  log "Root token saved to $INIT_DIR/root_token.env"
fi

# ----------------------------------------
# Bootstrap PKI (idempotent via || true)
# ----------------------------------------
if [ -f "/scripts/bootstrap-pki-api.sh" ]; then
  if [ -n "$ROOT_TOKEN" ]; then
    log "Running PKI bootstrap..."
    export VAULT_TOKEN="$ROOT_TOKEN"
    export VAULT_ADDR
    # Override hard-coded path in bootstrap script by setting ROOT_TOKEN_FILE env
    # The script reads from file; write token there temporarily
    mkdir -p /work/vault
    printf "VAULT_ROOT_TOKEN=%s\n" "$ROOT_TOKEN" > /work/vault/root_token.txt
    sh /scripts/bootstrap-pki-api.sh && log "✅ PKI bootstrap done." || log "⚠️  PKI bootstrap returned error (may already exist)."
  else
    log "⚠️  No root token found — skipping PKI bootstrap."
  fi
else
  log "No bootstrap-pki-api.sh found in /scripts — skipping PKI bootstrap."
fi

log "✅ vault-init complete."
