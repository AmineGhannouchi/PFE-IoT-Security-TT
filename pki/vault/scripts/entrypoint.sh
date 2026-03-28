#!/bin/sh
set -e

# --- Paramètres réseau via variables d'env ---
IP_ADDR="${IP_ADDR:-192.168.30.10/24}"
GW_ADDR="${GW_ADDR:-192.168.30.1}"
DNS_ADDR="${DNS_ADDR:-8.8.8.8}"
IFACE="${IFACE:-eth0}"

echo "[entrypoint] Config network: $IFACE ip=$IP_ADDR gw=$GW_ADDR dns=$DNS_ADDR"

# Installer iproute2 si absent (image vault est basée sur alpine)
# (vault official image utilise souvent distroless/alpine selon version)
# On tente, si déjà présent, pas grave.
apk add --no-cache iproute2 >/dev/null 2>&1 || true

# Appliquer IP + route
ip addr flush dev "$IFACE" || true
ip addr add "$IP_ADDR" dev "$IFACE"
ip link set "$IFACE" up
ip route del default >/dev/null 2>&1 || true
ip route add default via "$GW_ADDR"

# DNS
echo "nameserver $DNS_ADDR" > /etc/resolv.conf

# Variables Vault
export VAULT_ADDR="http://127.0.0.1:8200"

echo "[entrypoint] Starting Vault..."
exec vault server -config=/vault/config/vault.hcl