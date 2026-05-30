# Suricata 7 IDS — Nœud Docker GNS3

Nœud IDS de la **zone Analyse (VLAN 50, 192.168.50.10)** du laboratoire PFE IoT Security TT.
Reçoit le trafic miroir de la zone DMZ (port mirroring MikroTik), applique le parser MQTT
natif + les règles TLS/JA4, et produit `eve.json` consommé par Wazuh.

## Contenu

```
ids/suricata-gns3/
├── Dockerfile                      # Image basée sur jasonish/suricata:latest
├── config/
│   └── suricata.yaml               # Parser MQTT + TLS/JA4 + sortie eve.json
├── rules/
│   ├── mqtt-iot.rules              # SID 9000001-9000005 (rapport, fig. 4.6)
│   └── tls-iot.rules               # SID 1000001-1000014 (TLS 1.3 chiffré)
├── certs/                          # MÊME certificat que le ml-engine
│   ├── ca-chain.crt                #   (émis par Vault, CN=ml.iot-pfe.local)
│   ├── client.crt
│   └── client.key
├── scripts/
│   └── start-suricata-node.sh      # Config réseau GNS3 + lancement Suricata
└── README.md
```

> **Certificat** : le nœud réutilise le certificat du ml-engine (`CN=ml.iot-pfe.local`,
> rôle Vault `iot-services`). En IDS passif, Suricata ne s'en sert pas pour sniffer ; il
> sert d'**identité du nœud dans la PKI** du labo et à valider la chaîne TLS observée.

## Règles

| SID | Type | Détection | Sévérité |
|-----|------|-----------|----------|
| 9000001 | MQTT | Flood >50 CONNECT/10s même IP | High |
| 9000002 | MQTT | Topic `cmd/` suspect | Medium |
| 9000003 | MQTT | Payload PUBLISH > 4096 o | High |
| 9000004 | MQTT | Scan >20 CONNECT/5s | Medium |
| 9000005 | MQTT | SUBSCRIBE topic `admin` | High |
| 1000010 | TLS | Flood handshakes TLS (S5) | High |
| 1000011 | TLS | Réseau non-IoT vers broker | High |
| 1000013 | TLS | MQTT en clair sur 1883 (S1) | High |
| 1000014 | TLS | Version TLS < 1.3 | High |

---

## 1. Build de l'image (sur la GNS3 VM ou l'hôte Docker)

Copier le dossier sur la machine qui héberge Docker (GNS3 VM), puis :

```bash
cd ids/suricata-gns3
docker build -t pfe-suricata-ids:latest .
```

Vérifier le support MQTT :

```bash
docker run --rm pfe-suricata-ids:latest suricata --build-info | grep -i mqtt
```

---

## 2. Test rapide hors GNS3 (Docker standalone)

```bash
# Lancer en capturant l'interface hôte (mode test, sans config réseau GNS3)
docker run -d --name suricata-test \
  --net=host \
  --cap-add=NET_ADMIN --cap-add=SYS_NICE \
  -e NETWORK_AUTO_CONFIG=0 \
  -e SURICATA_IFACE=eth0 \
  -v /var/log/suricata:/var/log/suricata \
  pfe-suricata-ids:latest

# Suivre les logs
docker logs -f suricata-test

# Vérifier les alertes
docker exec suricata-test tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'
```

---

## 3. Intégration dans GNS3

### 3.1 Créer le template Docker

Dans GNS3 : **Edit → Preferences → Docker → Docker containers → New**

| Champ | Valeur |
|-------|--------|
| Image | `pfe-suricata-ids:latest` |
| Name | `suricata-ids` |
| Adapters | `1` |
| Start command | *(laisser vide — l'ENTRYPOINT gère le démarrage)* |
| Console type | `telnet` |
| Category | `Security devices` |

### 3.2 Variables d'environnement (onglet *Environment*)

```
SURICATA_IFACE=eth0
NODE_IP_CIDR=192.168.50.10/24
NODE_GATEWAY=192.168.50.1
NETWORK_AUTO_CONFIG=1
WAZUH_HOST=192.168.40.10
```

### 3.3 Câblage

- Relier l'adaptateur `eth0` du nœud `suricata-ids` au **switch de la zone Analyse** (VLAN 50).
- Configurer le **port mirroring** sur le MikroTik pour copier le trafic du `bridge-dmz`
  (VLAN 20) vers le port relié à Suricata (voir §4).

### 3.4 Démarrer

Démarrer le nœud, ouvrir la console. La séquence affiche :
config réseau → vérif certificat → test config → lancement Suricata.

---

## 4. Port mirroring MikroTik (alimenter Suricata)

Sur le MikroTik CHR, copier le trafic DMZ vers le port relié à Suricata :

```rsc
# Le trafic du VLAN 20 (DMZ) est copié vers l'interface reliée à la zone Analyse
/interface ethernet switch
set switch1 mirror-source=ether3 mirror-target=ether6
```

> `ether3` = bridge-dmz (VLAN 20), `ether6` = bridge-analyse (VLAN 50). Adapter aux noms réels.

Vérifier côté Suricata que le trafic arrive :

```bash
docker exec suricata-ids tcpdump -i eth0 -n port 8883 -c 5
```

---

## 5. Chaîne vers Wazuh

`eve.json` est écrit dans `/var/log/suricata/`. Côté Wazuh Manager (192.168.40.10),
ajouter dans `/var/ossec/etc/ossec.conf` :

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

Puis les règles de corrélation (escalade niveau 12) dans `local_rules.xml` — voir la
documentation Wazuh du projet.

Pipeline complet : **Suricata → eve.json → Wazuh → OpenSearch → Dashboard** (latence < 2 s).
