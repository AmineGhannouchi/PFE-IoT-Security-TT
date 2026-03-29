#!/bin/sh
set -e

IP_ADDR="${IP_ADDR:-192.168.30.10/24}"
GW_ADDR="${GW_ADDR:-192.168.30.1}"
DNS_ADDR="${DNS_ADDR:-1.1.1.1}"
IFACE="${IFACE:-eth0}"

apk add --no-cache iproute2 >/dev/null 2>&1 || true

ip addr flush dev "$IFACE" || true
ip addr add "$IP_ADDR" dev "$IFACE"
ip link set "$IFACE" up
ip route del default >/dev/null 2>&1 || true
ip route add default via "$GW_ADDR"

printf "nameserver %s\n" "$DNS_ADDR" > /etc/resolv.conf

export VAULT_ADDR="http://127.0.0.1:8200"
exec vault server -config=/vault/config/vault.hcl