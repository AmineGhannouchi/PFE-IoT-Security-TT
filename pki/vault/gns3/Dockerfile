FROM hashicorp/vault:1.15.4

# On ajoute notre config + entrypoint
COPY config/vault.hcl /vault/config/vault.hcl
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8200

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]