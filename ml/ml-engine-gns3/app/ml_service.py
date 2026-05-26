"""
ML Engine — Détection d'anomalies IoT en temps réel
Zone Analyse : 192.168.50.10
Souscrit à Mosquitto (192.168.20.10:8883) via mTLS
PFE IoT Security TT
"""

import os
import math
import time
import threading
import subprocess
import json
import logging
from collections import defaultdict, deque
from datetime import datetime

import numpy as np
import joblib
import paho.mqtt.client as mqtt
from flask import Flask, jsonify

# ─── Configuration ────────────────────────────────────────────────────────────
MOSQUITTO_HOST = os.getenv("MOSQUITTO_HOST", "192.168.20.10")
MOSQUITTO_PORT = int(os.getenv("MOSQUITTO_PORT", "8883"))
CA_CERT        = os.getenv("CA_CERT",   "./certs/ca-chain.crt")
CLIENT_CERT    = os.getenv("CLIENT_CERT","./certs/client.crt")
CLIENT_KEY     = os.getenv("CLIENT_KEY", "./certs/client.key")
MODELS_DIR     = os.getenv("MODELS_DIR", "./models")
API_PORT       = int(os.getenv("API_PORT", "5000"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S"
)
log = logging.getLogger("ml-engine")

# ─── Chargement des modèles ───────────────────────────────────────────────────
log.info("Chargement des modèles ML...")
rf_binary  = joblib.load(f"{MODELS_DIR}/random_forest_binary.pkl")
rf_multi   = joblib.load(f"{MODELS_DIR}/random_forest_multiclass.pkl")
iso_forest = joblib.load(f"{MODELS_DIR}/isolation_forest.pkl")
le_dict    = joblib.load(f"{MODELS_DIR}/label_encoders.pkl")
le_attack  = joblib.load(f"{MODELS_DIR}/label_encoder_attack.pkl")
log.info("Modèles charges : RandomForest (binaire + multi), IsolationForest")

# Ordre exact des features du modèle
FEATURES = [
    'payload_bytes','packet_count','session_duration_ms',
    'rtt_ms','jitter_ms','packet_loss_pct','retransmission_count',
    'topic_frequency_1m','duplicate_msg_rate_pct','payload_entropy',
    'qos_level','key_rotation_age_days','firmware_age_days',
    'conn_attempts_5m','failed_auth_1h',
    'anomaly_score_baseline','risk_score',
    'cpu_usage_pct','mem_usage_pct','signal_rssi_dbm','battery_pct',
    'protocol_enc','tls_version_enc','auth_method_enc','cert_status_enc',
    'src_zone_enc','dst_zone_enc','message_type_enc','device_type_enc'
]

# Encodage des catégories fixes (même mapping que l'entraînement)
def encode(col, val):
    le = le_dict.get(col)
    if le is None:
        return 0
    try:
        return int(le.transform([val])[0])
    except ValueError:
        return 0

CAT_DEFAULTS = {
    'protocol_enc':    encode('protocol',    'MQTT'),
    'tls_version_enc': encode('tls_version', 'TLSv1.3'),
    'auth_method_enc': encode('auth_method', 'certificate'),
    'cert_status_enc': encode('cert_status', 'valid'),
    'src_zone_enc':    encode('src_zone',    'IoT'),
    'dst_zone_enc':    encode('dst_zone',    'DMZ'),
    'message_type_enc':encode('message_type','PUBLISH'),
    'device_type_enc': encode('device_type', 'sensor'),
}

# ─── Métriques par client ─────────────────────────────────────────────────────
class ClientMetrics:
    def __init__(self):
        self.first_seen  = time.time()
        self.last_seen   = time.time()
        self.msg_count   = 0
        self.recent_msgs = deque(maxlen=100)   # dernières 60s
        self.payloads    = deque(maxlen=50)
        self.topics      = defaultdict(int)
        self.rtt_samples = deque(maxlen=20)

stats = defaultdict(ClientMetrics)
alerts = deque(maxlen=500)
predictions_total = {"normal": 0, "attack": 0}
lock = threading.Lock()

def shannon_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    freq = defaultdict(int)
    for b in data:
        freq[b] += 1
    n = len(data)
    return -sum((c/n) * math.log2(c/n) for c in freq.values())

def measure_rtt(host: str) -> float:
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-W", "1", host],
            capture_output=True, text=True, timeout=2
        )
        for line in result.stdout.split('\n'):
            if 'time=' in line:
                return float(line.split('time=')[1].split()[0])
    except Exception:
        pass
    return 10.0   # valeur par défaut si ping échoue

def build_feature_vector(client_id: str, payload: bytes,
                          topic: str, qos: int) -> np.ndarray:
    m = stats[client_id]
    now = time.time()

    # Features mesurables directement
    payload_bytes    = len(payload)
    payload_entropy  = shannon_entropy(payload)
    session_duration = (now - m.first_seen) * 1000  # ms

    # Fréquence messages dernière minute
    recent_1m = [t for t in m.recent_msgs if now - t < 60]
    topic_frequency_1m = len(recent_1m)

    # Taux de doublons (payloads identiques)
    dup_count = sum(1 for p in m.payloads if p == payload)
    duplicate_msg_rate = (dup_count / max(len(m.payloads), 1)) * 100

    # RTT vers Mosquitto (mis en cache toutes les 30s)
    if not m.rtt_samples or (now - m.last_seen) > 30:
        rtt = measure_rtt(MOSQUITTO_HOST)
        m.rtt_samples.append(rtt)
    rtt_ms   = np.mean(m.rtt_samples) if m.rtt_samples else 10.0
    jitter_ms = np.std(m.rtt_samples)  if len(m.rtt_samples) > 1 else 0.0

    vec = {
        'payload_bytes':          payload_bytes,
        'packet_count':           m.msg_count,
        'session_duration_ms':    session_duration,
        'rtt_ms':                 rtt_ms,
        'jitter_ms':              jitter_ms,
        'packet_loss_pct':        0.0,
        'retransmission_count':   0,
        'topic_frequency_1m':     topic_frequency_1m,
        'duplicate_msg_rate_pct': duplicate_msg_rate,
        'payload_entropy':        payload_entropy,
        'qos_level':              qos,
        'key_rotation_age_days':  0,
        'firmware_age_days':      0,
        'conn_attempts_5m':       topic_frequency_1m,
        'failed_auth_1h':         0,
        'anomaly_score_baseline': 0.0,
        'risk_score':             0.5,
        'cpu_usage_pct':          0.0,
        'mem_usage_pct':          0.0,
        'signal_rssi_dbm':        -70.0,
        'battery_pct':            100.0,
        **CAT_DEFAULTS
    }
    return np.array([vec[f] for f in FEATURES]).reshape(1, -1)

# ─── Prédiction ───────────────────────────────────────────────────────────────
def predict(client_id: str, topic: str, X: np.ndarray) -> dict:
    # RandomForest binaire
    rf_pred  = int(rf_binary.predict(X)[0])
    rf_proba = rf_binary.predict_proba(X)[0]
    is_attack = rf_pred == 0
    confidence = float(rf_proba[0] if is_attack else rf_proba[1])

    # RandomForest multi-classes (type d'attaque)
    attack_type = None
    if is_attack:
        mc_pred    = int(rf_multi.predict(X)[0])
        attack_type = str(le_attack.inverse_transform([mc_pred])[0])

    # IsolationForest
    iso_score = float(iso_forest.decision_function(X)[0])
    iso_label = "anomalie" if iso_forest.predict(X)[0] == -1 else "normal"

    result = {
        "timestamp":   datetime.utcnow().isoformat() + "Z",
        "client_id":   client_id,
        "topic":       topic,
        "rf_label":    "attack" if is_attack else "normal",
        "rf_confidence": round(confidence, 4),
        "attack_type": attack_type,
        "iso_label":   iso_label,
        "iso_score":   round(iso_score, 4),
    }

    with lock:
        if is_attack:
            predictions_total["attack"] += 1
            alerts.appendleft(result)
            log.warning(
                f"ATTAQUE DETECTEE | client={client_id} | "
                f"type={attack_type} | confiance={confidence:.2%} | "
                f"iso={iso_score:.3f}"
            )
        else:
            predictions_total["normal"] += 1
            log.info(
                f"Normal | client={client_id} | topic={topic} | "
                f"iso={iso_score:.3f}"
            )

    return result

# ─── MQTT callbacks ───────────────────────────────────────────────────────────
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        log.info(f"Connecte a Mosquitto {MOSQUITTO_HOST}:{MOSQUITTO_PORT}")
        client.subscribe("#", qos=1)
        log.info("Souscrit a tous les topics (#)")
    else:
        log.error(f"Echec connexion MQTT, code={rc}")

def on_message(client, userdata, msg):
    client_id = msg.topic.split("/")[-1] if "/" in msg.topic else "unknown"

    with lock:
        m = stats[client_id]
        m.msg_count  += 1
        m.last_seen   = time.time()
        m.recent_msgs.append(time.time())
        m.payloads.append(msg.payload)
        m.topics[msg.topic] += 1

    X = build_feature_vector(client_id, msg.payload, msg.topic, msg.qos)
    predict(client_id, msg.topic, X)

def on_disconnect(client, userdata, rc):
    log.warning(f"Deconnecte de Mosquitto (rc={rc}), reconnexion...")

# ─── Flask API ────────────────────────────────────────────────────────────────
app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify({"status": "ok", "models": ["rf_binary", "rf_multi", "iso_forest"]})

@app.route("/stats")
def get_stats():
    with lock:
        return jsonify({
            "predictions": dict(predictions_total),
            "clients":     len(stats),
            "alerts_count": len(alerts),
        })

@app.route("/alerts")
def get_alerts():
    with lock:
        return jsonify(list(alerts))

@app.route("/alerts/latest")
def get_latest_alert():
    with lock:
        return jsonify(alerts[0] if alerts else {})

# ─── Main ─────────────────────────────────────────────────────────────────────
def start_mqtt():
    client = mqtt.Client(client_id="ml-engine-analyser")
    client.tls_set(ca_certs=CA_CERT, certfile=CLIENT_CERT, keyfile=CLIENT_KEY)
    client.on_connect    = on_connect
    client.on_message    = on_message
    client.on_disconnect = on_disconnect

    log.info(f"Connexion a Mosquitto {MOSQUITTO_HOST}:{MOSQUITTO_PORT}...")
    client.connect(MOSQUITTO_HOST, MOSQUITTO_PORT, keepalive=60)
    client.loop_forever()

if __name__ == "__main__":
    log.info("=== ML Engine — PFE IoT Security TT ===")
    log.info(f"Zone Analyse : 192.168.50.10")
    log.info(f"Mosquitto    : {MOSQUITTO_HOST}:{MOSQUITTO_PORT}")

    mqtt_thread = threading.Thread(target=start_mqtt, daemon=True)
    mqtt_thread.start()

    app.run(host="0.0.0.0", port=API_PORT)
