# =====================================================
# Suricata 7 IDS — Docker GNS3
# Zone Analyse : 192.168.50.10 (VLAN 50)
# Parser MQTT natif + règles TLS/JA4
# PFE IoT Security TT — Mohamed Amine Ghannouchi
# =====================================================
FROM jasonish/suricata:latest

LABEL maintainer="Mohamed Amine Ghannouchi"
LABEL zone="Analyse (VLAN 50) — 192.168.50.11"
LABEL description="Suricata 7 IDS — parser MQTT + TLS/JA4 — PFE IoT Security TT"

# Outils réseau pour l'intégration GNS3 (config IP statique, diagnostic)
# Détection automatique du gestionnaire de paquets (Alpine / Fedora-Rocky / Debian)
RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache iproute2 iputils tcpdump net-tools openssl ca-certificates jq bash; \
    elif command -v microdnf >/dev/null 2>&1; then \
        microdnf install -y iproute iputils tcpdump net-tools openssl ca-certificates jq bash && microdnf clean all; \
    elif command -v dnf >/dev/null 2>&1; then \
        dnf install -y iproute iputils tcpdump net-tools openssl ca-certificates jq bash && dnf clean all; \
    elif command -v yum >/dev/null 2>&1; then \
        yum install -y iproute iputils tcpdump net-tools openssl ca-certificates jq bash && yum clean all; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && apt-get install -y --no-install-recommends iproute2 iputils-ping tcpdump net-tools openssl ca-certificates jq bash && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Aucun gestionnaire de paquets supporté" && exit 1; \
    fi

# Configuration Suricata personnalisée
COPY config/suricata.yaml /etc/suricata/suricata.yaml

# Règles personnalisées (MQTT du rapport + TLS/JA4)
COPY rules/ /var/lib/suricata/rules/

# Certificats — MÊME identité que le ml-engine (émis par Vault, rôle iot-services)
# Utilisés pour : validation de la chaîne TLS observée + identité du nœud dans la PKI du labo
COPY certs/ /etc/suricata/certs/

# Script de démarrage GNS3 : configuration réseau puis lancement de Suricata
COPY scripts/start-suricata-node.sh /usr/local/bin/start-suricata-node.sh
RUN chmod +x /usr/local/bin/start-suricata-node.sh \
    && mkdir -p /var/log/suricata \
    && chmod 600 /etc/suricata/certs/client.key

# Paramètres réseau par défaut (surchargés par les variables d'environnement GNS3)
ENV SURICATA_IFACE=eth0 \
    NODE_IP_CIDR=192.168.50.11/24 \
    NODE_GATEWAY=192.168.50.1 \
    NETWORK_AUTO_CONFIG=1 \
    IFACE_WAIT_SECONDS=10

# stdout non-bufferisé → logs visibles en temps réel dans la console GNS3
ENTRYPOINT ["/usr/local/bin/start-suricata-node.sh"]
