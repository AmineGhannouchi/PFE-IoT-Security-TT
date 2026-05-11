FROM python:3.11-alpine

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    openssl \
    bind-tools \
    iproute2 \
    iputils \
    tcpdump \
    net-tools \
    busybox-extras \
    tzdata \
  && update-ca-certificates

WORKDIR /opt/pfe-attack

COPY infrastructure/docker/images/pfe-attack-mqtt/requirements.txt /opt/pfe-attack/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /opt/pfe-attack/requirements.txt

COPY tests/attacks/mqtt_flood_attack.py /opt/pfe-attack/mqtt_flood_attack.py
COPY infrastructure/docker/images/pfe-attack-mqtt/run-mqtt-flood.sh /usr/local/bin/run-mqtt-flood.sh

RUN chmod +x /usr/local/bin/run-mqtt-flood.sh \
    && mkdir -p /work/attacks /work/vault/certs /work/fleet-sim/certs

VOLUME ["/work"]

CMD ["sleep", "infinity"]