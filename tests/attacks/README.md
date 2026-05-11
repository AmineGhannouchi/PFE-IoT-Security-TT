# Tests d'attaque GNS3

## Scénario A1 — Flood MQTT/TLS contrôlé

Script : `tests/attacks/mqtt_flood_attack.py`

Objectif : générer un nombre borné de connexions TLS et de publications MQTT vers le broker Mosquitto pour déclencher les règles Suricata existantes sans sortir du lab.

### Prérequis dans le nœud attaquant GNS3

- Image toolbox reconstruite à partir de `infrastructure/docker/images/pfe-toolbox/Dockerfile`
- CA : `/work/vault/certs/ca-chain.crt`
- Certificat device : `/work/fleet-sim/certs/<device-id>/client.crt`
- Clé device : `/work/fleet-sim/certs/<device-id>/client.key`

### Copie du script vers la toolbox

Depuis la GNS3 VM :

```bash
sudo docker cp /opt/PFE-IoT-Security-TT/tests/attacks/mqtt_flood_attack.py <TOOLBOX_CONTAINER>:/work/attacks/mqtt_flood_attack.py
sudo docker exec -u 0 -it <TOOLBOX_CONTAINER> sh -lc "chmod +x /work/attacks/mqtt_flood_attack.py"
```

### Commande de démonstration recommandée

```bash
python3 /work/attacks/mqtt_flood_attack.py \
  --broker-host 192.168.20.10 \
  --device-id dev_048797 \
  --cert-file /work/fleet-sim/certs/dev_048797/client.crt \
  --key-file /work/fleet-sim/certs/dev_048797/client.key \
  --connections 24 \
  --workers 6 \
  --messages-per-connection 8 \
  --payload-bytes 768
```

### Artefacts produits dans la toolbox

- `/work/attacks/A1-flood/<timestamp>/summary.json`
- `/work/attacks/A1-flood/<timestamp>/failures.json` si au moins une connexion échoue

### Preuves à capturer pour le rapport

1. Topologie GNS3 avant lancement
2. Console du nœud attaquant pendant l'exécution du script
3. Capture GNS3 sur le lien Mosquitto ↔ switch DMZ
4. Extrait `eve.json` ou `fast.log` avec le SID `1000010` ou `1000012`
5. Retour à l'état nominal après fin du script