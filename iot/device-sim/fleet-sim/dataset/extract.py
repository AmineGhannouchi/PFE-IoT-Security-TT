import pandas as pd

CSV = "F:/Projets/PFE-IoT-Security-TT/iot/device-sim/fleet-sim/dataset/iot.csv"  # <-- à ajuster
N = 50

df = pd.read_csv(CSV)
df = df[df["protocol"].astype(str).str.upper() == "MQTT"].copy()

top = df["device_id"].value_counts().head(N).index.tolist()
with open("F:/Projets/PFE-IoT-Security-TT/iot/device-sim/fleet-sim/dataset/devices_top50.txt", "w", encoding="utf-8") as f:
    for d in top:
        f.write(d + "\n")

print("Wrote:", "F:/Projets/PFE-IoT-Security-TT/iot/device-sim/fleet-sim/dataset/devices_top50.txt")
print("First 10:", top[:10])