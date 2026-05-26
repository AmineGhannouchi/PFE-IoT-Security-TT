FROM python:3.11-alpine

RUN apk add --no-cache ca-certificates openssl iproute2 && update-ca-certificates

WORKDIR /app
COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app/fleet_sim.py /app/fleet_sim.py
COPY certs/ /app/certs/
COPY dataset/ /app/dataset/
COPY app/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]