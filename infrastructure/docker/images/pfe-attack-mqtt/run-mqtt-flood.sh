#!/bin/sh
set -eu

SCRIPT="/opt/pfe-attack/mqtt_flood_attack.py"

BROKER_HOST="${BROKER_HOST:-192.168.20.10}"
BROKER_PORT="${BROKER_PORT:-8883}"
DEVICE_ID="${DEVICE_ID:-dev_048797}"
TENANT_ID="${TENANT_ID:-tt-demo}"
MESSAGE_TYPE="${MESSAGE_TYPE:-telemetry}"
CA_FILE="${CA_FILE:-/work/vault/certs/ca-chain.crt}"
CERT_FILE="${CERT_FILE:-/work/fleet-sim/certs/${DEVICE_ID}/client.crt}"
KEY_FILE="${KEY_FILE:-/work/fleet-sim/certs/${DEVICE_ID}/client.key}"
CONNECTIONS="${CONNECTIONS:-24}"
WORKERS="${WORKERS:-6}"
MESSAGES_PER_CONNECTION="${MESSAGES_PER_CONNECTION:-8}"
PAYLOAD_BYTES="${PAYLOAD_BYTES:-768}"
QOS="${QOS:-0}"
DELAY_MS="${DELAY_MS:-10}"
HOLD_MS="${HOLD_MS:-0}"
KEEPALIVE="${KEEPALIVE:-30}"
CLIENT_PREFIX="${CLIENT_PREFIX:-a1-flood}"
OUTPUT_DIR="${OUTPUT_DIR:-/work/attacks/A1-flood}"

mkdir -p "$OUTPUT_DIR"

exec python3 "$SCRIPT" \
  --broker-host "$BROKER_HOST" \
  --broker-port "$BROKER_PORT" \
  --device-id "$DEVICE_ID" \
  --tenant-id "$TENANT_ID" \
  --message-type "$MESSAGE_TYPE" \
  --ca-file "$CA_FILE" \
  --cert-file "$CERT_FILE" \
  --key-file "$KEY_FILE" \
  --connections "$CONNECTIONS" \
  --workers "$WORKERS" \
  --messages-per-connection "$MESSAGES_PER_CONNECTION" \
  --payload-bytes "$PAYLOAD_BYTES" \
  --qos "$QOS" \
  --delay-ms "$DELAY_MS" \
  --hold-ms "$HOLD_MS" \
  --keepalive "$KEEPALIVE" \
  --client-prefix "$CLIENT_PREFIX" \
  --output-dir "$OUTPUT_DIR" \
  "$@"