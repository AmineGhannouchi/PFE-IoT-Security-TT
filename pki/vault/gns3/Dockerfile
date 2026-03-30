# ============================================
# PFE IoT Security TT — Vault (GNS3 container)
# ============================================
FROM hashicorp/vault:1.15.4

USER root

# Outils utiles pour init + parsing + debug
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3 \
    ca-certificates \
  && update-ca-certificates

# Dossiers
RUN mkdir -p /pfe/scripts /pfe/out /vault/config /vault/data \
  && chown -R vault:vault /pfe /vault

# Config Vault (file storage, HTTP listener)
COPY vault.hcl /vault/config/vault.hcl

# Script init/unseal + PKI
COPY init_pki.sh /pfe/scripts/init_pki.sh
RUN chmod +x /pfe/scripts/init_pki.sh

USER vault

EXPOSE 8200

# Démarrage Vault (init déclenché manuellement ensuite)
ENTRYPOINT ["vault", "server", "-config=/vault/config/vault.hcl"]