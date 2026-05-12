#!/bin/sh
set -eu

AUTO_START="${AUTO_START:-0}"
SHELL_BIN="${SHELL_BIN:-/bin/sh}"
BROKER_HOST="${BROKER_HOST:-192.168.20.10}"
NODE_IFACE="${NODE_IFACE:-eth0}"
NODE_IP_CIDR="${NODE_IP_CIDR:-192.168.10.101/24}"
NODE_GATEWAY="${NODE_GATEWAY:-192.168.10.1}"
NETWORK_AUTO_CONFIG="${NETWORK_AUTO_CONFIG:-1}"
IFACE_WAIT_SECONDS="${IFACE_WAIT_SECONDS:-10}"
GATEWAY_WAIT_SECONDS="${GATEWAY_WAIT_SECONDS:-10}"
CERT_BOOTSTRAP_DIR="${CERT_BOOTSTRAP_DIR:-/opt/pfe-attack/bootstrap-certs}"

bootstrap_certificates() {
  embedded_entry="$(find "$CERT_BOOTSTRAP_DIR" -mindepth 1 -print -quit 2>/dev/null || true)"
  current_entry="$(find /work/fleet-sim/certs -mindepth 1 -print -quit 2>/dev/null || true)"

  mkdir -p /work/fleet-sim/certs /work/vault/certs

  if [ -z "$embedded_entry" ]; then
    echo "[certs] No embedded certificate bundle found in ${CERT_BOOTSTRAP_DIR}"
    return 0
  fi

  echo "[certs] Embedded bundle : ${CERT_BOOTSTRAP_DIR}"

  if [ -z "$current_entry" ]; then
    echo "[certs] Populating /work/fleet-sim/certs from embedded bundle"
    cp -R "$CERT_BOOTSTRAP_DIR"/. /work/fleet-sim/certs/
  else
    echo "[certs] Existing /work/fleet-sim/certs detected, preserving current contents"
  fi

  if [ -f "$CERT_BOOTSTRAP_DIR/ca-chain.crt" ] && [ ! -f /work/fleet-sim/certs/ca-chain.crt ]; then
    cp "$CERT_BOOTSTRAP_DIR/ca-chain.crt" /work/fleet-sim/certs/ca-chain.crt
  fi

  if [ -f /work/fleet-sim/certs/ca-chain.crt ] && [ ! -f /work/vault/certs/ca-chain.crt ]; then
    echo "[certs] Installing CA chain into /work/vault/certs"
    cp /work/fleet-sim/certs/ca-chain.crt /work/vault/certs/ca-chain.crt
  fi
}

wait_for_interface() {
  attempt=1
  while [ "$attempt" -le "$IFACE_WAIT_SECONDS" ]; do
    if ip link show dev "$NODE_IFACE" >/dev/null 2>&1; then
      return 0
    fi
    echo "[net] Waiting for interface ${NODE_IFACE} (${attempt}/${IFACE_WAIT_SECONDS})"
    sleep 1
    attempt=$((attempt + 1))
  done

  echo "[net] Interface ${NODE_IFACE} not found"
  return 1
}

configure_network() {
  echo "[net] Interface    : ${NODE_IFACE}"
  echo "[net] Broker host  : ${BROKER_HOST}"

  wait_for_interface

  if [ "$NETWORK_AUTO_CONFIG" = "1" ]; then
    echo "[net] Applying static IPv4 configuration"
    ip addr flush dev "$NODE_IFACE"
    ip addr add "$NODE_IP_CIDR" dev "$NODE_IFACE"
    ip link set "$NODE_IFACE" up
    ip route replace default via "$NODE_GATEWAY"
  else
    echo "[net] NETWORK_AUTO_CONFIG=0, keeping existing IP configuration"
    ip link set "$NODE_IFACE" up
  fi

  echo "[net] IPv4 status"
  ip -4 addr show dev "$NODE_IFACE"
  echo "[net] Routing table"
  ip route show
}

wait_for_gateway() {
  attempt=1
  while [ "$attempt" -le "$GATEWAY_WAIT_SECONDS" ]; do
    if ping -c 1 -W 1 "$NODE_GATEWAY" >/dev/null 2>&1; then
      echo "[net] Gateway ${NODE_GATEWAY} reachable"
      return 0
    fi
    echo "[net] Waiting for gateway ${NODE_GATEWAY} (${attempt}/${GATEWAY_WAIT_SECONDS})"
    sleep 1
    attempt=$((attempt + 1))
  done

  echo "[net] Gateway ${NODE_GATEWAY} is still unreachable"
  return 1
}

check_broker_route() {
  if ip route get "$BROKER_HOST" >/dev/null 2>&1; then
    echo "[net] Route to broker ${BROKER_HOST} is present"
  else
    echo "[net] No route to broker ${BROKER_HOST}"
  fi
}

if [ "$AUTO_START" = "1" ]; then
  MODE_LABEL="auto-start"
else
  MODE_LABEL="manuel"
fi

echo "=== atk-iot :: GNS3 node launcher ==="
echo "Mode         : ${MODE_LABEL}"
echo "Start script : /usr/local/bin/start-mqtt-flood-node.sh"
echo "Wrapper      : /usr/local/bin/run-mqtt-flood.sh"
echo ""

bootstrap_certificates
echo ""

configure_network
wait_for_gateway || true
check_broker_route
echo ""

if [ "$AUTO_START" = "1" ]; then
  echo "[1/3] AUTO_START=1 detected"
  echo "[2/3] Running flood scenario before opening the shell"
  set +e
  /usr/local/bin/run-mqtt-flood.sh "$@"
  status=$?
  set -e
  echo "[3/3] Flood scenario finished with exit code ${status}"
  echo ""
fi

echo "Console actions to show in screenshots:"
echo "  ip addr show eth0"
echo "  ip route show"
echo "  ping -c 2 192.168.20.10"
echo "  run-mqtt-flood.sh"
echo "  ls -1 /work/attacks/A1-flood"
echo "  cat /work/attacks/A1-flood/<timestamp>/summary.json"
echo ""
echo "Opening interactive shell..."
exec "$SHELL_BIN"