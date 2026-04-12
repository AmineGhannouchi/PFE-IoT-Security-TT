#!/usr/bin/env python3
"""
Analyse du eve.json Suricata - Phase 6
PFE IoT Security TT
"""
import json
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
from collections import Counter

EVE = Path("results/analysis/step6/suricata-v2/eve.json")

events = []
with open(EVE) as f:
    for line in f:
        line = line.strip()
        if line:
            events.append(json.loads(line))

df = pd.DataFrame(events)
df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)

print(f"\nTotal events      : {len(df)}")
print(f"Event types       : {df['event_type'].value_counts().to_dict()}")

# TLS connections
tls = df[df["event_type"] == "tls"].copy()
print(f"\nTLS connections   : {len(tls)}")
if "tls" in tls.columns:
    ja4_counts = Counter(
        e.get("ja4", "N/A") for e in tls["tls"].dropna()
    )
    print(f"JA4 fingerprints  : {dict(ja4_counts)}")

# Alerts
alerts = df[df["event_type"] == "alert"].copy()
print(f"\nAlerts            : {len(alerts)}")
if not alerts.empty:
    sig_counts = alerts["alert"].apply(lambda x: x.get("signature", "?") if isinstance(x, dict) else "?")
    print(sig_counts.value_counts().to_string())

# Timeline des connexions TLS
if not tls.empty:
    tls = tls.set_index("timestamp").sort_index()
    fig, ax = plt.subplots(figsize=(12, 4))
    tls.resample("5s")["src_ip"].count().plot(ax=ax, color="steelblue")
    ax.set_title("Connexions TLS/MQTT par tranche de 5 secondes")
    ax.set_xlabel("Temps")
    ax.set_ylabel("Nombre de connexions")
    plt.tight_layout()
    plt.savefig("results/analysis/step6/tls_connections_timeline.png", dpi=150)
    print("\n==> Graphique sauvegardé : results/analysis/step6/tls_connections_timeline.png")

print("\nDone.")