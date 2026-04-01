FROM eclipse-mosquitto:2.0

# Config + ACL
COPY config/mosquitto.conf /mosquitto/config/mosquitto.conf
COPY config/aclfile /mosquitto/config/aclfile

# Certs (public + private key)
COPY certs/ /mosquitto/config/certs/

EXPOSE 8883