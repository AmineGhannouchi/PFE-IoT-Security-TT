# 📍 Plan d'Adressage IP — PFE IoT Security TT

## Réseau Global

| Zone | VLAN | Réseau | Masque | Passerelle |
|------|------|--------|--------|-----------|
| Management | 1 | 192.168.1.0 | /24 | 192.168.1.1 |
| IoT Devices | 10 | 192.168.10.0 | /24 | 192.168.10.1 |
| DMZ (Brokers) | 20 | 192.168.20.0 | /24 | 192.168.20.1 |
| PKI | 30 | 192.168.30.0 | /24 | 192.168.30.1 |
| SIEM | 40 | 192.168.40.0 | /24 | 192.168.40.1 |
| Analyse/ML | 50 | 192.168.50.0 | /24 | 192.168.50.1 |

## Équipements Réseau

| Équipement | Interface | IP | Rôle |
|-----------|-----------|-----|------|
| pfSense | WAN (em0) | DHCP | Accès Internet |
| pfSense | LAN (em1) | 192.168.1.1/24 | Trunk vers MikroTik |
| MikroTik CHR | ether1 | 192.168.1.2/24 | Trunk pfSense |
| MikroTik CHR | vlan10 | 192.168.10.1/24 | GW Zone IoT |
| MikroTik CHR | vlan20 | 192.168.20.1/24 | GW Zone DMZ |
| MikroTik CHR | vlan30 | 192.168.30.1/24 | GW Zone PKI |
| MikroTik CHR | vlan40 | 192.168.40.1/24 | GW Zone SIEM |
| MikroTik CHR | vlan50 | 192.168.50.1/24 | GW Zone Analyse |

## IoT Devices (VLAN 10)

| Device | IP | Protocole | Port |
|--------|----|-----------|------|
| iot-device-01 (Température) | 192.168.10.11 | MQTT/TLS | 8883 |
| iot-device-02 (Humidité) | 192.168.10.12 | MQTT/TLS | 8883 |
| iot-device-03 (Pression) | 192.168.10.13 | CoAP/DTLS | 5684 |
| iot-device-04 (HTTP Client) | 192.168.10.14 | HTTPS | 443 |

## Zone DMZ (VLAN 20)

| Service | IP | Port | Protocole |
|---------|----|------|-----------|
| Mosquitto MQTT Broker | 192.168.20.10 | 8883 | MQTT/TLS |
| CoAP Gateway | 192.168.20.11 | 5684 | CoAP/DTLS |
| nginx HTTP Gateway | 192.168.20.12 | 443 | HTTPS |

## Zone PKI (VLAN 30)

| Service | IP | Port |
|---------|----|------|
| HashiCorp Vault | 192.168.30.10 | 8200 |

## Zone SIEM (VLAN 40)

| Service | IP | Port |
|---------|----|------|
| Wazuh Manager | 192.168.40.10 | 1514, 1515, 55000 |
| OpenSearch | 192.168.40.11 | 9200, 9300 |
| OpenSearch Dashboards | 192.168.40.12 | 5601 |

## Zone Analyse (VLAN 50)

| Service | IP | Port |
|---------|----|------|
| Suricata IDS | 192.168.50.10 | — (passif) |
| Zeek | 192.168.50.11 | — (passif) |
| ML Engine / Jupyter | 192.168.50.12 | 8888 |