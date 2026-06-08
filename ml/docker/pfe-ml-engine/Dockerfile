# =====================================================
# pfe-ml-engine — Analyse ML temps réel
# Zone Analyse : 192.168.50.12:8888
# PFE IoT Security TT
# =====================================================
FROM python:3.10-slim

WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Dépendances Python
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code de l'application
COPY app/ .

# Modèles ML entraînés
COPY models/ /app/models/

# Certificats mTLS (à remplir via volume ou COPY)
# - /app/certs/ca-chain.crt
# - /app/certs/ml-engine.crt
# - /app/certs/ml-engine.key

EXPOSE 8888

COPY app/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
