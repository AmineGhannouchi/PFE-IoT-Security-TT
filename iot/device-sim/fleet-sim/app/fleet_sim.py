import argparse
import json
import os
import random
import ssl
import time
from datetime import datetime
from dateutil import parser as dtparser

import pandas as pd
import paho.mqtt.client as mqtt


def pad_payload(payload: dict, target_bytes: int) -> dict:
    s = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    if len(s.encode("utf-8")) >= target_bytes:
        return payload
    # pad with deterministic-ish data
    pad_len = max(0, target_bytes - len(s.encode("utf-8")) - 20)
    payload["padding"] = ("X" * pad_len)
    return payload


def build_topic(tenant_id: str, device_id: str, message_type: str) -> str:
    # keep it simple and deterministic
    mt = str(message_type).strip().lower()
    if mt == "":
        mt = "telemetry"
    return f"iot/{tenant_id}/{device_id}/{mt}"


def connect_mqtt(broker_host, broker_port, cafile, certfile, keyfile, client_id, tls_version="TLS1.3"):
    client = mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv311, clean_session=True)

    # TLS context
    ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=cafile)
    ctx.load_cert_chain(certfile=certfile, keyfile=keyfile)

    # Prefer TLS 1.3 when available
    if hasattr(ssl, "TLSVersion"):
        ctx.minimum_version = ssl.TLSVersion.TLSv1_3 if tls_version == "TLS1.3" else ssl.TLSVersion.TLSv1_2

    client.tls_set_context(ctx)
    client.tls_insecure_set(False)

    client.connect(broker_host, broker_port, keepalive=60)
    client.loop_start()
    return client


def replay_device(df_dev: pd.DataFrame, args, device_id: str):
    tenant_id = df_dev["tenant_id"].iloc[0]
    cert_dir = args.certs_dir

    cafile = os.path.join(cert_dir, "ca-chain.crt")
    certfile = os.path.join(cert_dir, device_id, "client.crt")
    keyfile = os.path.join(cert_dir, device_id, "client.key")

    client = connect_mqtt(
        args.broker_host, args.broker_port, cafile, certfile, keyfile,
        client_id=device_id, tls_version="TLS1.3"
    )

    # sort by timestamp
    df_dev = df_dev.sort_values("timestamp")
    last_ts = None

    for _, row in df_dev.iterrows():
        ts = dtparser.parse(str(row["timestamp"]))
        if last_ts is not None:
            delta = (ts - last_ts).total_seconds()
            sleep_s = max(0.0, delta / args.speed)
            sleep_s = min(sleep_s, args.max_sleep)
            time.sleep(sleep_s)
        last_ts = ts

        attack_type = str(row.get("attack_type", "normal")).lower()
        label_secure = int(row.get("label_secure", 1))

        topic = build_topic(row["tenant_id"], row["device_id"], row.get("message_type", "telemetry"))
        qos = int(row.get("qos_level", 1)) if str(row.get("qos_level", "")).strip() != "" else 1

        payload = {
            "ts": str(row["timestamp"]),
            "tenant_id": row["tenant_id"],
            "device_id": row["device_id"],
            "device_type": row.get("device_type"),
            "gateway_id": row.get("gateway_id"),
            "message_type": row.get("message_type"),
            "rtt_ms": row.get("rtt_ms"),
            "jitter_ms": row.get("jitter_ms"),
            "packet_loss_pct": row.get("packet_loss_pct"),
            "retransmission_count": row.get("retransmission_count"),
            "payload_entropy": row.get("payload_entropy"),
            "risk_score": row.get("risk_score"),
            "risk_level": row.get("risk_level"),
            "attack_type": attack_type,
            "label_secure": label_secure,
        }
        target_bytes = int(row.get("payload_bytes", 256))
        payload = pad_payload(payload, target_bytes)

        # Attack behaviors
        if label_secure == 0 and attack_type == "dos":
            # burst: publish same payload multiple times quickly
            for _ in range(args.dos_burst):
                client.publish(topic, json.dumps(payload), qos=qos)
            continue

        if label_secure == 0 and attack_type == "replay":
            # duplicate publish (simulate replay/duplicate)
            client.publish(topic, json.dumps(payload), qos=qos)
            client.publish(topic, json.dumps(payload), qos=qos)
            continue

        client.publish(topic, json.dumps(payload), qos=qos)

    client.loop_stop()
    client.disconnect()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--broker-host", default="192.168.20.10")
    ap.add_argument("--broker-port", type=int, default=8883)
    ap.add_argument("--devices", type=int, default=100)
    ap.add_argument("--speed", type=float, default=60.0, help="Replay speedup factor")
    ap.add_argument("--max-sleep", type=float, default=1.0)
    ap.add_argument("--certs-dir", default="/app/certs")
    ap.add_argument("--dos-burst", type=int, default=20)
    args = ap.parse_args()

    df = pd.read_csv(args.csv)

    # Keep MQTT only for this phase
    df = df[df["protocol"].astype(str).str.upper() == "MQTT"].copy()
    if df.empty:
        raise SystemExit("No MQTT rows found in CSV")

    # Pick devices with most rows to get meaningful traffic
    counts = df["device_id"].value_counts()
    chosen = list(counts.head(args.devices).index)

    print(f"Loaded {len(df)} MQTT rows. Simulating {len(chosen)} devices (top by frequency).")

    for device_id in chosen:
        df_dev = df[df["device_id"] == device_id]
        print(f"== Device {device_id}: rows={len(df_dev)}")
        replay_device(df_dev, args, device_id)

    print("Done.")


if __name__ == "__main__":
    main()