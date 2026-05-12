# Image Docker GNS3 — Attaque MQTT/TLS contrôlée

Cette image embarque directement le script `mqtt_flood_attack.py` afin de lancer le scénario A1 depuis un nœud Docker GNS3, sans copie manuelle du script dans le conteneur.

## Fichiers inclus

- `mqtt_flood_attack.py` copié depuis `tests/attacks/mqtt_flood_attack.py`
- wrapper `/usr/local/bin/run-mqtt-flood.sh`

## Build depuis la GNS3 VM

Depuis la racine du dépôt cloné dans la GNS3 VM :

```bash
cd /opt/PFE-IoT-Security-TT
sudo docker build -t pfe-attack-mqtt:latest -f infrastructure/docker/images/pfe-attack-mqtt/Dockerfile .
```

## Intégration dans GNS3

Créer un template Docker basé sur l'image `pfe-attack-mqtt:latest`.

- Console command : `bash`
- Adapters : `1`
- Persistent volume : `/work`
- Start command : `/usr/local/bin/start-mqtt-flood-node.sh`

Le lanceur affiche dans la console GNS3 les actions utiles pour les captures d'écran, puis ouvre un shell interactif.
Le `CMD` du Dockerfile doit rester `sleep infinity` : si le lanceur est placé directement comme commande par défaut de l'image, la console GNS3 peut ne plus s'attacher correctement au n\oe ud.
Les certificats éventuellement présents dans `iot/device-sim/fleet-sim/certs` sont embarqués dans l'image sous `/opt/pfe-attack/bootstrap-certs`, puis recopiés vers `/work/fleet-sim/certs` au démarrage si le volume `/work` est vide.

## Mode auto-start optionnel

Pour lancer automatiquement le scénario dès le démarrage du n\oe ud `atk-iot`, définir dans le template ou le n\oe ud GNS3 :

- Environment : `AUTO_START=1`

Le script configure d'abord l'interface réseau du conteneur, vérifie la route vers le broker, exécute ensuite `run-mqtt-flood.sh`, affiche le code retour, puis laisse un shell ouvert pour les vérifications et screenshots de fin d'exécution.

Variables d'environnement utiles :

- `AUTO_START=1` : lance automatiquement le scénario A1.
- `NETWORK_AUTO_CONFIG=1` : applique automatiquement l'IP statique et la route par défaut.
- `NODE_IP_CIDR=192.168.10.101/24` : adresse du n\oe ud `atk-iot`.
- `NODE_GATEWAY=192.168.10.1` : passerelle du VLAN IoT.
- `BROKER_HOST=192.168.20.10` : IP du broker Mosquitto à joindre.

Pour un n\oe ud externe de type `atk-ext`, remplacer par exemple :

```text
AUTO_START=1
NODE_IP_CIDR=192.168.40.101/24
NODE_GATEWAY=192.168.40.1
BROKER_HOST=192.168.20.10
```

## Réseau recommandé

- `atk-iot` sur le switch IoT : `192.168.10.101/24`, gateway `192.168.10.1`
- `atk-ext` sur un réseau non autorisé vers le broker, par exemple SIEM : `192.168.40.101/24`, gateway `192.168.40.1`

Configuration IP depuis la GNS3 VM :

```bash
sudo docker exec -u 0 -it <ATK_IOT> sh -lc "ip addr flush dev eth0; ip addr add 192.168.10.101/24 dev eth0; ip link set eth0 up; ip route replace default via 192.168.10.1"
sudo docker exec -u 0 -it <ATK_EXT> sh -lc "ip addr flush dev eth0; ip addr add 192.168.40.101/24 dev eth0; ip link set eth0 up; ip route replace default via 192.168.40.1"
```

## Certificats à monter dans `/work`

Le script attend :

- `/work/vault/certs/ca-chain.crt`
- `/work/fleet-sim/certs/<device-id>/client.crt`
- `/work/fleet-sim/certs/<device-id>/client.key`

Si le volume GNS3 `/work` est vide au premier démarrage, le lanceur tente de l'initialiser automatiquement depuis `/opt/pfe-attack/bootstrap-certs`. Si aucun certificat n'est embarqué dans l'image, il faut toujours monter ou générer ces fichiers manuellement.

## Exécution dans le nœud GNS3

### Séquence console recommandée pour les screenshots

À l'ouverture de la console, le lanceur rappelle déjà les commandes utiles. La séquence recommandée pour le rapport est la suivante :

```bash
ip addr show eth0
ping -c 2 192.168.20.10
run-mqtt-flood.sh
ls -1 /work/attacks/A1-flood
cat /work/attacks/A1-flood/<timestamp>/summary.json
```

### Variante 1 — commande simple

```bash
run-mqtt-flood.sh
```

### Variante 2 — avec variables d'environnement

```bash
DEVICE_ID=dev_048797 CONNECTIONS=12 WORKERS=4 MESSAGES_PER_CONNECTION=5 PAYLOAD_BYTES=512 run-mqtt-flood.sh
```

### Variante 3 — avec paramètres explicites

```bash
run-mqtt-flood.sh --connections 24 --workers 6 --messages-per-connection 8 --payload-bytes 768
```

## Résultats

Les artefacts sont générés dans :

- `/work/attacks/A1-flood/<timestamp>/summary.json`
- `/work/attacks/A1-flood/<timestamp>/failures.json` si des connexions échouent

## Captures à faire pour le rapport

1. Topologie GNS3 avant lancement
2. Console du nœud `atk-iot` pendant `run-mqtt-flood.sh`
3. Capture GNS3 sur le lien `Mosquitto ↔ switch DMZ`
4. Vue Suricata avec les SID `1000010` ou `1000012`
5. Vue MikroTik si le scénario est lancé depuis un nœud externe bloqué