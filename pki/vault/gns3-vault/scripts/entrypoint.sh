#!/bin/sh
set -e
echo "[vault-entrypoint] starting vault..."
exec vault server -config=/vault/config/vault.hcl