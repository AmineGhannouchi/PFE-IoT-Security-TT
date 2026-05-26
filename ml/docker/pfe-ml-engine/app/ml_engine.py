"""
pfe-ml-engine — Analyse ML IoT en temps reel
Zone Analyse : 192.168.50.12 | Dashboard : http://192.168.50.12:8888
PFE IoT Security TT
"""

import collections
import json
import math
import ssl
import threading
import time
from datetime import datetime

import joblib
import numpy as np
import paho.mqtt.client as mqtt
from flask import Flask, jsonify, render_template_string

# ─────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────
BROKER_HOST = "192.168.20.10"
BROKER_PORT = 8883
MQTT_TOPIC  = "iot/#"

CAFILE   = "/app/certs/ca-chain.crt"
CERTFILE = "/app/certs/ml-engine.crt"
KEYFILE  = "/app/certs/ml-engine.key"

MODELS_DIR = "/app/models/"

FEATURES = [
    "payload_bytes", "packet_count", "session_duration_ms",
    "rtt_ms", "jitter_ms", "packet_loss_pct", "retransmission_count",
    "topic_frequency_1m", "duplicate_msg_rate_pct", "payload_entropy",
    "qos_level", "key_rotation_age_days", "firmware_age_days",
    "conn_attempts_5m", "failed_auth_1h",
    "anomaly_score_baseline", "risk_score",
    "cpu_usage_pct", "mem_usage_pct", "signal_rssi_dbm", "battery_pct",
    "protocol_enc", "tls_version_enc", "auth_method_enc", "cert_status_enc",
    "src_zone_enc", "dst_zone_enc", "message_type_enc", "device_type_enc",
]

# ─────────────────────────────────────────────────────────
# Chargement des modèles
# ─────────────────────────────────────────────────────────
print("[ML] Chargement des modèles...")
iso_forest  = joblib.load(f"{MODELS_DIR}isolation_forest.pkl")
rf_binary   = joblib.load(f"{MODELS_DIR}random_forest_binary.pkl")
rf_multi    = joblib.load(f"{MODELS_DIR}random_forest_multiclass.pkl")
le_dict     = joblib.load(f"{MODELS_DIR}label_encoders.pkl")
le_attack   = joblib.load(f"{MODELS_DIR}label_encoder_attack.pkl")
print("[ML] Modèles charges : IsolationForest + RF Binary + RF Multiclass")

# ─────────────────────────────────────────────────────────
# État partagé (thread-safe avec deque/Counter)
# ─────────────────────────────────────────────────────────
results = collections.deque(maxlen=200)
topic_window  = collections.defaultdict(list)
device_msgs   = collections.defaultdict(list)
stats = {
    "total": 0, "normal": 0, "attack": 0, "anomaly": 0,
    "attack_types": collections.Counter(),
}
lock = threading.Lock()

# ─────────────────────────────────────────────────────────
# Extraction des features
# ─────────────────────────────────────────────────────────
def encode_cat(col, value):
    le = le_dict.get(col)
    if le is None:
        return 0
    try:
        return int(le.transform([str(value)])[0])
    except Exception:
        return 0


def payload_entropy(s):
    if not s:
        return 0.0
    freq = collections.Counter(s)
    n = len(s)
    return round(-sum((c / n) * math.log2(c / n) for c in freq.values()), 4)


def extract_features(raw_payload, topic, qos):
    now = time.time()

    try:
        data = json.loads(raw_payload)
    except Exception:
        data = {}

    device_id  = str(data.get("device_id", "unknown"))
    payload_str = raw_payload if isinstance(raw_payload, str) \
                  else raw_payload.decode("utf-8", errors="replace")
    p_bytes = len(payload_str.encode("utf-8"))

    # Fréquence topic sur 60s
    topic_window[topic].append(now)
    topic_window[topic] = [t for t in topic_window[topic] if now - t <= 60]
    freq_1m = len(topic_window[topic])

    # Taux de messages dupliqués
    fp = payload_str[:80]
    device_msgs[device_id].append(fp)
    if len(device_msgs[device_id]) > 30:
        device_msgs[device_id] = device_msgs[device_id][-30:]
    dup_rate = (device_msgs[device_id].count(fp) - 1) / max(len(device_msgs[device_id]), 1) * 100

    message_type = str(data.get("message_type") or "telemetry")
    device_type  = str(data.get("device_type")  or "sensor")

    feat = {
        "payload_bytes":          p_bytes,
        "packet_count":           freq_1m,
        "session_duration_ms":    60000.0,
        "rtt_ms":                 float(data.get("rtt_ms")                or 50.0),
        "jitter_ms":              float(data.get("jitter_ms")             or 5.0),
        "packet_loss_pct":        float(data.get("packet_loss_pct")       or 0.0),
        "retransmission_count":   float(data.get("retransmission_count")  or 0.0),
        "topic_frequency_1m":     float(freq_1m),
        "duplicate_msg_rate_pct": round(dup_rate, 2),
        "payload_entropy":        float(data.get("payload_entropy") or payload_entropy(payload_str)),
        "qos_level":              int(qos),
        "key_rotation_age_days":  30.0,
        "firmware_age_days":      90.0,
        "conn_attempts_5m":       float(min(freq_1m, 20)),
        "failed_auth_1h":         0.0,
        "anomaly_score_baseline": 0.0,
        "risk_score":             float(data.get("risk_score") or 0.0),
        "cpu_usage_pct":          50.0,
        "mem_usage_pct":          50.0,
        "signal_rssi_dbm":        -65.0,
        "battery_pct":            80.0,
        "protocol_enc":           encode_cat("protocol",     "MQTT"),
        "tls_version_enc":        encode_cat("tls_version",  "TLSv1.3"),
        "auth_method_enc":        encode_cat("auth_method",  "certificate"),
        "cert_status_enc":        encode_cat("cert_status",  "valid"),
        "src_zone_enc":           encode_cat("src_zone",     "IoT"),
        "dst_zone_enc":           encode_cat("dst_zone",     "DMZ"),
        "message_type_enc":       encode_cat("message_type", message_type),
        "device_type_enc":        encode_cat("device_type",  device_type),
    }
    return feat, device_id, data


# ─────────────────────────────────────────────────────────
# Inférence ML
# ─────────────────────────────────────────────────────────
def run_inference(feat):
    X = np.array([[feat[f] for f in FEATURES]])

    iso_score = float(iso_forest.decision_function(X)[0])
    is_anomaly = iso_forest.predict(X)[0] == -1

    rf_pred  = int(rf_binary.predict(X)[0])
    rf_proba = float(rf_binary.predict_proba(X)[0][0])
    is_attack = rf_pred == 0

    attack_type = "normal"
    if is_attack:
        at = rf_multi.predict(X)[0]
        attack_type = str(le_attack.inverse_transform([at])[0])

    return {
        "is_anomaly":   is_anomaly,
        "iso_score":    round(iso_score, 4),
        "is_attack":    is_attack,
        "attack_proba": round(rf_proba * 100, 1),
        "attack_type":  attack_type,
    }


# ─────────────────────────────────────────────────────────
# Callbacks MQTT
# ─────────────────────────────────────────────────────────
def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"[MQTT] Connecte a {BROKER_HOST}:{BROKER_PORT}")
        client.subscribe(MQTT_TOPIC, qos=1)
        print(f"[MQTT] Abonne a '{MQTT_TOPIC}'")
    else:
        print(f"[MQTT] Erreur connexion rc={rc}")


def on_disconnect(client, userdata, rc, properties=None):
    print(f"[MQTT] Deconnecte (rc={rc}), reconnexion...")


def on_message(client, userdata, msg):
    try:
        feat, device_id, raw = extract_features(msg.payload, msg.topic, msg.qos)
        res  = run_inference(feat)

        entry = {
            "ts":           datetime.now().strftime("%H:%M:%S"),
            "topic":        msg.topic,
            "device_id":    device_id,
            "bytes":        feat["payload_bytes"],
            "rtt_ms":       feat["rtt_ms"],
            "freq_1m":      int(feat["topic_frequency_1m"]),
            "is_anomaly":   res["is_anomaly"],
            "iso_score":    res["iso_score"],
            "is_attack":    res["is_attack"],
            "attack_proba": res["attack_proba"],
            "attack_type":  res["attack_type"],
            "risk_score":   feat["risk_score"],
        }

        with lock:
            results.appendleft(entry)
            stats["total"] += 1
            if res["is_attack"]:
                stats["attack"] += 1
                stats["attack_types"][res["attack_type"]] += 1
            elif res["is_anomaly"]:
                stats["anomaly"] += 1
            else:
                stats["normal"] += 1

        # Log console
        if res["is_attack"]:
            tag = f"\033[91m[ATTACK:{res['attack_type'].upper()}]\033[0m"
        elif res["is_anomaly"]:
            tag = f"\033[93m[ANOMALY]\033[0m"
        else:
            tag = "\033[92m[NORMAL]\033[0m"

        print(f"{entry['ts']} {tag:40s} device={device_id:25s} "
              f"rtt={feat['rtt_ms']:6.1f}ms  proba={res['attack_proba']:5.1f}%  "
              f"iso={res['iso_score']:+.3f}")

    except Exception as e:
        print(f"[ERROR] {e}")


# ─────────────────────────────────────────────────────────
# Dashboard Flask
# ─────────────────────────────────────────────────────────
app = Flask(__name__)

DASHBOARD_HTML = """<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PFE ML Engine — IoT Security Dashboard</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', sans-serif; background: #0f1117; color: #e0e0e0; }
    header { background: #1a1d27; padding: 16px 24px; border-bottom: 2px solid #00bcd4;
             display: flex; align-items: center; justify-content: space-between; }
    header h1 { font-size: 1.3rem; color: #00bcd4; }
    header span { font-size: 0.8rem; color: #888; }
    .cards { display: flex; gap: 16px; padding: 20px 24px; flex-wrap: wrap; }
    .card { flex: 1; min-width: 160px; background: #1a1d27; border-radius: 8px;
            padding: 20px; text-align: center; border: 1px solid #2a2d3e; }
    .card .val { font-size: 2.2rem; font-weight: bold; margin-bottom: 4px; }
    .card .lbl { font-size: 0.8rem; color: #888; text-transform: uppercase; letter-spacing: 1px; }
    .card.total .val { color: #64b5f6; }
    .card.normal .val { color: #66bb6a; }
    .card.attack .val { color: #ef5350; }
    .card.anomaly .val { color: #ffa726; }
    .section { padding: 0 24px 20px; }
    .section h2 { font-size: 0.9rem; color: #888; text-transform: uppercase;
                  letter-spacing: 1px; margin-bottom: 12px; }
    table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
    th { background: #1a1d27; padding: 8px 10px; text-align: left;
         color: #888; font-weight: 500; border-bottom: 1px solid #2a2d3e; }
    td { padding: 7px 10px; border-bottom: 1px solid #1e2130; }
    tr:hover td { background: #1e2130; }
    .badge { padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 600; }
    .b-normal  { background: #1b5e20; color: #a5d6a7; }
    .b-attack  { background: #b71c1c; color: #ffcdd2; }
    .b-anomaly { background: #e65100; color: #ffe0b2; }
    .bar-wrap  { display: flex; gap: 12px; flex-wrap: wrap; padding: 0 24px 24px; }
    .bar-item  { flex: 1; min-width: 140px; background: #1a1d27; border-radius: 6px;
                 padding: 12px; border: 1px solid #2a2d3e; }
    .bar-label { font-size: 0.78rem; color: #aaa; margin-bottom: 6px; }
    .bar-bg    { background: #0f1117; border-radius: 4px; height: 8px; overflow: hidden; }
    .bar-fill  { height: 8px; border-radius: 4px; transition: width 0.5s; }
    .bar-count { font-size: 0.9rem; font-weight: bold; margin-top: 4px; }
    .status-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block;
                  margin-right: 6px; animation: pulse 2s infinite; }
    .dot-ok  { background: #66bb6a; }
    .dot-err { background: #ef5350; animation: none; }
    @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }
  </style>
</head>
<body>
<header>
  <h1>&#9632; PFE ML Engine — IoT Security</h1>
  <span id="status"><span class="status-dot dot-ok"></span>En attente de données...</span>
</header>

<div class="cards">
  <div class="card total">
    <div class="val" id="c-total">0</div>
    <div class="lbl">Messages total</div>
  </div>
  <div class="card normal">
    <div class="val" id="c-normal">0</div>
    <div class="lbl">Normal</div>
  </div>
  <div class="card attack">
    <div class="val" id="c-attack">0</div>
    <div class="lbl">Attaques</div>
  </div>
  <div class="card anomaly">
    <div class="val" id="c-anomaly">0</div>
    <div class="lbl">Anomalies</div>
  </div>
</div>

<div class="section">
  <h2>Types d'attaques détectées</h2>
  <div class="bar-wrap" id="attack-bars"></div>
</div>

<div class="section">
  <h2>Flux récents</h2>
  <table>
    <thead>
      <tr>
        <th>Heure</th><th>Device</th><th>Topic</th>
        <th>Octets</th><th>RTT(ms)</th><th>Fréq/min</th>
        <th>Statut</th><th>Type attaque</th><th>Proba%</th><th>ISO score</th>
      </tr>
    </thead>
    <tbody id="tbody"></tbody>
  </table>
</div>

<script>
const COLORS = {
  dos:'#ef5350', replay:'#ab47bc', mitm:'#ff7043',
  scan:'#ffca28', brute_force:'#26c6da', normal:'#66bb6a'
};

async function refresh() {
  const [statsR, resR] = await Promise.all([
    fetch('/api/stats').then(r=>r.json()),
    fetch('/api/results').then(r=>r.json())
  ]);

  document.getElementById('c-total').textContent   = statsR.total;
  document.getElementById('c-normal').textContent  = statsR.normal;
  document.getElementById('c-attack').textContent  = statsR.attack;
  document.getElementById('c-anomaly').textContent = statsR.anomaly;

  document.getElementById('status').innerHTML =
    `<span class="status-dot dot-ok"></span>${statsR.total} messages | ` +
    `${statsR.attack_pct}% attaques`;

  // Barres types attaques
  const barsDiv = document.getElementById('attack-bars');
  barsDiv.innerHTML = '';
  const types = statsR.attack_types;
  const maxCount = Math.max(1, ...Object.values(types));
  for (const [t, n] of Object.entries(types)) {
    const pct = Math.round(n / maxCount * 100);
    const color = COLORS[t] || '#90a4ae';
    barsDiv.innerHTML += `
      <div class="bar-item">
        <div class="bar-label">${t}</div>
        <div class="bar-bg"><div class="bar-fill" style="width:${pct}%;background:${color}"></div></div>
        <div class="bar-count" style="color:${color}">${n}</div>
      </div>`;
  }
  if (Object.keys(types).length === 0)
    barsDiv.innerHTML = '<span style="color:#555;font-size:0.8rem">Aucune attaque détectée</span>';

  // Tableau
  const tbody = document.getElementById('tbody');
  tbody.innerHTML = '';
  for (const r of resR) {
    let badge, cls;
    if (r.is_attack) {
      badge = `<span class="badge b-attack">ATTACK</span>`;
      cls = 'style="background:#1a0000"';
    } else if (r.is_anomaly) {
      badge = `<span class="badge b-anomaly">ANOMALY</span>`;
      cls = 'style="background:#1a0d00"';
    } else {
      badge = `<span class="badge b-normal">NORMAL</span>`;
      cls = '';
    }
    tbody.innerHTML += `<tr ${cls}>
      <td>${r.ts}</td>
      <td style="font-family:monospace;font-size:0.75rem">${r.device_id}</td>
      <td style="font-family:monospace;font-size:0.72rem;color:#888">${r.topic}</td>
      <td>${r.bytes}</td>
      <td>${r.rtt_ms}</td>
      <td>${r.freq_1m}</td>
      <td>${badge}</td>
      <td style="color:${COLORS[r.attack_type]||'#aaa'}">${r.attack_type}</td>
      <td>${r.attack_proba}%</td>
      <td style="color:${r.iso_score<0?'#ef5350':'#66bb6a'}">${r.iso_score}</td>
    </tr>`;
  }
}

setInterval(refresh, 2000);
refresh();
</script>
</body>
</html>"""


@app.route("/")
def dashboard():
    return render_template_string(DASHBOARD_HTML)


@app.route("/api/results")
def api_results():
    with lock:
        return jsonify(list(results)[:50])


@app.route("/api/stats")
def api_stats():
    with lock:
        total = stats["total"]
        return jsonify({
            "total":        total,
            "normal":       stats["normal"],
            "attack":       stats["attack"],
            "anomaly":      stats["anomaly"],
            "normal_pct":   round(stats["normal"]  / max(total, 1) * 100, 1),
            "attack_pct":   round(stats["attack"]  / max(total, 1) * 100, 1),
            "anomaly_pct":  round(stats["anomaly"] / max(total, 1) * 100, 1),
            "attack_types": dict(stats["attack_types"]),
        })


# ─────────────────────────────────────────────────────────
# Thread MQTT
# ─────────────────────────────────────────────────────────
def start_mqtt():
    import os
    client = mqtt.Client(client_id="pfe-ml-engine", protocol=mqtt.MQTTv311,
                         clean_session=True)

    if os.path.exists(CAFILE) and os.path.exists(CERTFILE) and os.path.exists(KEYFILE):
        ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=CAFILE)
        ctx.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
        if hasattr(ssl, "TLSVersion"):
            ctx.minimum_version = ssl.TLSVersion.TLSv1_3
        client.tls_set_context(ctx)
        print("[MQTT] mTLS configure")
    else:
        print("[MQTT] ATTENTION: certificats manquants, connexion sans TLS")

    client.on_connect    = on_connect
    client.on_disconnect = on_disconnect
    client.on_message    = on_message

    while True:
        try:
            client.connect(BROKER_HOST, BROKER_PORT, keepalive=60)
            client.loop_forever()
        except Exception as e:
            print(f"[MQTT] Connexion echouee: {e} — retry dans 5s")
            time.sleep(5)


if __name__ == "__main__":
    print("=" * 60)
    print(" PFE ML Engine — IoT Security Analysis")
    print(f" Broker  : {BROKER_HOST}:{BROKER_PORT}")
    print(f" Topic   : {MQTT_TOPIC}")
    print(f" Dashboard : http://192.168.50.12:8888")
    print("=" * 60)

    mqtt_thread = threading.Thread(target=start_mqtt, daemon=True)
    mqtt_thread.start()

    app.run(host="0.0.0.0", port=8888, debug=False, threaded=True)
