# =====================================================
# ML Engine — Docker GNS3
# Zone Analyse : 192.168.50.10 (VLAN 50)
# PFE IoT Security TT
# =====================================================
FROM python:3.11-slim

WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Dépendances Python
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code source
COPY app/ .

# Modèles ML (entraînés)
COPY models/ ./models/

# Certificats mTLS pour connexion à Mosquitto
COPY certs/ ./certs/

# API REST
EXPOSE 5000

CMD ["python", "ml_service.py"]
