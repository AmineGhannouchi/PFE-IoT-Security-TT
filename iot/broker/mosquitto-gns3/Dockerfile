FROM eclipse-mosquitto:2.0

# Config + ACL
COPY config/mosquitto.conf /mosquitto/config/mosquitto.conf
COPY config/aclfile /mosquitto/config/aclfile

# Certificates are NOT baked in — they are provided at runtime
# via a named Docker volume (pfe-mosquitto-certs) populated by
# mosquitto-cert-init (issue-mosquitto-cert-api.sh → Vault PKI).
# Expected files in /mosquitto/config/certs/:
#   ca-chain.crt   — CA chain (root + intermediate)
#   mosquitto.crt  — server certificate
#   mosquitto.key  — server private key (never committed to VCS)

RUN mkdir -p /mosquitto/config/certs /mosquitto/data /mosquitto/log \
    && chown -R mosquitto:mosquitto /mosquitto

EXPOSE 8883