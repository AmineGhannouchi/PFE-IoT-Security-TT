FROM python:3.11-alpine

RUN apk add --no-cache ca-certificates openssl && update-ca-certificates

WORKDIR /app
COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app/fleet_sim.py /app/fleet_sim.py
COPY certs/ /app/certs/
COPY dataset/ /app/dataset/

CMD ["python", "/app/fleet_sim.py", "--csv", "/app/dataset/iot_communication_security_dataset_sample.csv"]