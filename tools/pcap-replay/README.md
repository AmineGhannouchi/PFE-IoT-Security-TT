# Rejeu pcap — Démo de la chaîne de détection

Rejoue une capture réseau (`wireshark.pcapng`) pour alimenter Suricata et faire
apparaître des alertes dans Wazuh, sans dépendre du fleet-sim en direct.

- **Auto** : 60 s après le démarrage de Wazuh, le flux est envoyé une fois (service systemd).
- **Manuel** : une commande précise déclenche l'envoi immédiat.

## Fichiers
- `pcap_replay.py` — script de rejeu (scapy)
- `pfe-pcap-replay.service` — service systemd (autostart après Wazuh)

## Prérequis et installation (sur la VM Wazuh)

```bash
# 1. Outils
sudo dnf install -y python3 python3-pip tcpdump
sudo pip3 install scapy

# 2. Dossier de travail + script
sudo mkdir -p /opt/pfe
sudo cp pcap_replay.py /opt/pfe/pcap_replay.py
sudo chmod +x /opt/pfe/pcap_replay.py
```

Transférer le pcap depuis le PC Windows (PowerShell) :
```powershell
scp "F:\Projets\wireshark.pcapng" wazuh-user@192.168.200.121:/tmp/wireshark.pcapng
```
Puis sur la VM :
```bash
sudo mv /tmp/wireshark.pcapng /opt/pfe/wireshark.pcapng
```

## Mode AUTO (60 s après Wazuh)

```bash
sudo cp pfe-pcap-replay.service /etc/systemd/system/pfe-pcap-replay.service
sudo systemctl daemon-reload
sudo systemctl enable pfe-pcap-replay.service
sudo systemctl start pfe-pcap-replay.service      # test sans reboot

# Suivre l'exécution
journalctl -u pfe-pcap-replay.service -f
```

Au prochain démarrage de la VM, Wazuh se lance, puis 60 s plus tard le flux est rejoué.

## Mode MANUEL (commande précise)

Envoi immédiat, à la demande :
```bash
sudo python3 /opt/pfe/pcap_replay.py --now --iface eth0
```

Options utiles :
```bash
# Répéter 3 fois (ex: déclencher les seuils DoS)
sudo python3 /opt/pfe/pcap_replay.py --now --iface eth0 --loops 3

# Ralentir l'émission (10 ms entre paquets)
sudo python3 /opt/pfe/pcap_replay.py --now --iface eth0 --inter 0.01
```

## Vérification

```bash
# Côté Suricata : voir les alertes générées
docker exec <nom-suricata> tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'

# Côté Wazuh : alertes ingérées
sudo tail -f /var/ossec/logs/alerts/alerts.json
```
Puis dans le Dashboard Wazuh, filtrer sur les règles `suricata` / SID `9000001`+.

## IMPORTANT — interface de rejeu

`--iface` doit être l'interface **reliée au segment que Suricata surveille**.
Le rejeu réémet les trames au niveau 2 ; Suricata doit donc les recevoir sur son
interface d'écoute (via le hub/miroir GNS3). Si Suricata est sur un autre segment,
adapter le câblage GNS3 ou lancer ce rejeu depuis un nœud du bon VLAN.

> Alternative 100 % fiable (hors réseau) : analyse offline du pcap par Suricata
> `suricata -r /opt/pfe/wireshark.pcapng -l /var/log/suricata` — génère directement
> `eve.json` lu par Wazuh, sans dépendre du câblage.
