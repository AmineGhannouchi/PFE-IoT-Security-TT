# ================================================
# PFE IoT Security TT — MikroTik CHR Configuration
# ================================================

# --- Identité ---
/system identity set name=mikrotik-pfe

# --- Créer les bridges par VLAN ---
/interface bridge
add name=bridge-iot     comment="Zone IoT - VLAN 10"
add name=bridge-dmz     comment="Zone DMZ - VLAN 20"
add name=bridge-pki     comment="Zone PKI - VLAN 30"
add name=bridge-siem    comment="Zone SIEM - VLAN 40"
add name=bridge-analyse comment="Zone Analyse - VLAN 50"

# --- Assigner les ports aux bridges ---
/interface bridge port
add bridge=bridge-iot     interface=ether2
add bridge=bridge-dmz     interface=ether3
add bridge=bridge-pki     interface=ether4
add bridge=bridge-siem    interface=ether5
add bridge=bridge-analyse interface=ether6

# --- Adresses IP des passerelles (routeur L3) ---
/ip address
add address=192.168.1.2/24    interface=ether1    comment="Uplink vers pfSense"
add address=192.168.10.1/24   interface=bridge-iot     comment="GW Zone IoT"
add address=192.168.20.1/24   interface=bridge-dmz     comment="GW Zone DMZ"
add address=192.168.30.1/24   interface=bridge-pki     comment="GW Zone PKI"
add address=192.168.40.1/24   interface=bridge-siem    comment="GW Zone SIEM"
add address=192.168.50.1/24   interface=bridge-analyse comment="GW Zone Analyse"

# --- Route par défaut vers pfSense ---
/ip route
add dst-address=0.0.0.0/0 gateway=192.168.1.1 comment="Default via pfSense"

# --- DNS ---
/ip dns set servers=8.8.8.8,1.1.1.1

# --- Firewall — ACL inter-VLANs ---
/ip firewall filter

# Accepter trafic établi
add chain=forward connection-state=established,related action=accept comment="Accept established"

# IoT → DMZ (broker uniquement)
add chain=forward src-address=192.168.10.0/24 dst-address=192.168.20.10 \
    protocol=tcp dst-port=8883 action=accept comment="IoT→MQTT TLS"
add chain=forward src-address=192.168.10.0/24 dst-address=192.168.20.11 \
    protocol=udp dst-port=5684 action=accept comment="IoT→CoAP DTLS"
add chain=forward src-address=192.168.10.0/24 dst-address=192.168.20.12 \
    protocol=tcp dst-port=443 action=accept comment="IoT→HTTP HTTPS"

# IoT → PKI (demande certificat)
add chain=forward src-address=192.168.10.0/24 dst-address=192.168.30.10 \
    protocol=tcp dst-port=8200 action=accept comment="IoT→Vault PKI"

# DMZ → PKI (vérification certificat)
add chain=forward src-address=192.168.20.0/24 dst-address=192.168.30.10 \
    protocol=tcp dst-port=8200 action=accept comment="DMZ→Vault verify"

# DMZ → SIEM (logs)
add chain=forward src-address=192.168.20.0/24 dst-address=192.168.40.10 \
    protocol=tcp dst-port=1514 action=accept comment="DMZ→Wazuh logs"

# Analyse → SIEM (alertes)
add chain=forward src-address=192.168.50.0/24 dst-address=192.168.40.10 \
    protocol=tcp dst-port=1514 action=accept comment="Analyse→Wazuh alertes"

# SIEM interne
add chain=forward src-address=192.168.40.0/24 dst-address=192.168.40.0/24 \
    action=accept comment="SIEM interne libre"

# Accès Dashboards depuis partout
add chain=forward dst-address=192.168.40.12 \
    protocol=tcp dst-port=5601 action=accept comment="OpenSearch Dashboards"

# BLOQUER IoT → SIEM direct
add chain=forward src-address=192.168.10.0/24 dst-address=192.168.40.0/24 \
    action=drop comment="BLOCK IoT→SIEM direct"

# BLOQUER IoT → Analyse direct
add chain=forward src-address=192.168.10.0/24 dst-address=192.168.50.0/24 \
    action=drop comment="BLOCK IoT→Analyse direct"

# Drop tout le reste (inter-VLAN non autorisé)
add chain=forward action=drop comment="DROP all other inter-VLAN"

# --- Port Mirroring (copie trafic DMZ vers Suricata) ---
/interface ethernet
set ether3 comment="Zone DMZ — miroir vers Suricata"

/tool sniffer
set filter-interface=bridge-dmz filter-stream=yes

# --- NTP ---
/system ntp client
set enabled=yes servers=216.239.35.0

# --- Sauvegarder la configuration ---
/system backup save name=pfe-iot-security-config