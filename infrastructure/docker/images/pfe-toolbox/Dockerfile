# ==========================================================
# PFE IoT Security TT — Toolbox image (no runtime apk needed)
# ==========================================================
FROM alpine:3.20

# Paquets utiles réseau + sécurité + python
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
    nmap \
    jq \
    python3 \
    py3-pip \
    git \
    busybox-extras \
    tzdata \
  && update-ca-certificates

RUN python3 -m pip install --no-cache-dir \
    paho-mqtt==2.1.0

# Confort
RUN adduser -D pfe && mkdir -p /work && chown -R pfe:pfe /work
WORKDIR /work
USER pfe

CMD ["bash"]