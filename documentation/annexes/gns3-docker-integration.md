# Intégration Docker dans GNS3 (via GNS3 VM)

## Objectif
Centraliser les services (Vault, Mosquitto, SIEM, IDS, Devices) comme nœuds Docker dans GNS3.

## Approche retenue
- Docker Engine : GNS3 VM
- Segmentation : 1 switch Ethernet par zone (IoT/DMZ/PKI/SIEM/Analyse)
- Routage inter-zones : MikroTik CHR (L3) + pfSense (Firewall/NAT)

## Plan d’adressage test
- alpine-iot : 192.168.10.100/24 gw 192.168.10.1
- alpine-dmz : 192.168.20.100/24 gw 192.168.20.1
- alpine-pki : 192.168.30.100/24 gw 192.168.30.1
- alpine-siem : 192.168.40.100/24 gw 192.168.40.1
- alpine-analyse : 192.168.50.100/24 gw 192.168.50.1

## Tests
- Ping vers la passerelle
- Ping inter-zones selon ACL