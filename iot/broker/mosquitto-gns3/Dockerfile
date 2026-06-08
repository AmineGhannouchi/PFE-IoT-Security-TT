FROM eclipse-mosquitto:2.0

# Config + ACL
COPY config/mosquitto.conf /mosquitto/config/mosquitto.conf
COPY config/aclfile /mosquitto/config/aclfile

# Certs (public + private key)
COPY certs/ /mosquitto/config/certs/

# rsyslog pour forwarding des logs vers Wazuh (192.168.40.10:514)
RUN apk add --no-cache rsyslog iproute2

# Config rsyslog
COPY config/rsyslog.conf /etc/rsyslog.conf

# Script de démarrage (lance rsyslog + mosquitto)
COPY config/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8883

ENTRYPOINT ["/start.sh"]