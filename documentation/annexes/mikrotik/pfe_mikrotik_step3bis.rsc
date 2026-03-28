
# 2026-03-28 15:55:32 by RouterOS 7.16
# software id =
#
/interface bridge
add comment="Zone Analyse - VLAN 50" name=bridge-analyse
add comment="Zone DMZ - VLAN 20" name=bridge-dmz
add comment="Zone IoT - VLAN 10" name=bridge-iot
add comment="Zone PKI - VLAN 30" name=bridge-pki
add comment="Zone SIEM - VLAN 40" name=bridge-siem
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] comment="Zone DMZ  miroir vers Suricata" disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
set [ find default-name=ether6 ] disable-running-check=no
set [ find default-name=ether7 ] disable-running-check=no
set [ find default-name=ether8 ] disable-running-check=no
/port
set 0 name=serial0
/interface bridge port
add bridge=bridge-iot interface=ether2
add bridge=bridge-dmz interface=ether3
add bridge=bridge-pki interface=ether4
add bridge=bridge-siem interface=ether5
add bridge=bridge-analyse interface=ether6
/ip address
add address=192.168.1.2/24 comment="Uplink vers pfSense" interface=ether1 network=192.168.1.0
add address=192.168.10.1/24 comment="GW Zone IoT" interface=bridge-iot network=192.168.10.0
add address=192.168.20.1/24 comment="GW Zone DMZ" interface=bridge-dmz network=192.168.20.0
add address=192.168.30.1/24 comment="GW Zone PKI" interface=bridge-pki network=192.168.30.0
add address=192.168.40.1/24 comment="GW Zone SIEM" interface=bridge-siem network=192.168.40.0
add address=192.168.50.1/24 comment="GW Zone Analyse" interface=bridge-analyse network=192.168.50.0
/ip dhcp-client
add interface=ether1
/ip dns
set servers=8.8.8.8,1.1.1.1
/ip firewall filter
add action=accept chain=forward comment="Accept established" connection-state=established,related
add action=accept chain=forward comment="IoTMQTT TLS" dst-address=192.168.20.10 dst-port=8883 protocol=tcp src-address=\
    192.168.10.0/24
add action=accept chain=forward comment="IoTCoAP DTLS" dst-address=192.168.20.11 dst-port=5684 protocol=udp src-address=\
    192.168.10.0/24
add action=accept chain=forward comment="IoTHTTP HTTPS" dst-address=192.168.20.12 dst-port=443 protocol=tcp src-address=\
    192.168.10.0/24
add action=accept chain=forward comment="IoTVault PKI" dst-address=192.168.30.10 dst-port=8200 protocol=tcp src-address=\
    192.168.10.0/24
add action=accept chain=forward comment="DMZVault verify" dst-address=192.168.30.10 dst-port=8200 protocol=tcp \
    src-address=192.168.20.0/24
add action=accept chain=forward comment="DMZWazuh logs" dst-address=192.168.40.10 dst-port=1514 protocol=tcp src-address=\
    192.168.20.0/24
add action=accept chain=forward comment="AnalyseWazuh alertes" dst-address=192.168.40.10 dst-port=1514 protocol=tcp \
    src-address=192.168.50.0/24
add action=accept chain=forward comment="SIEM interne libre" dst-address=192.168.40.0/24 src-address=192.168.40.0/24
add action=accept chain=forward comment="OpenSearch Dashboards" dst-address=192.168.40.12 dst-port=5601 protocol=tcp
add action=drop chain=forward comment="BLOCK IoTSIEM direct" dst-address=192.168.40.0/24 src-address=192.168.10.0/24
add action=drop chain=forward comment="BLOCK IoTAnalyse direct" dst-address=192.168.50.0/24 src-address=192.168.10.0/24
add action=accept chain=forward comment="ALLOW ICMP IoT -> pfSense (debug)" dst-address=192.168.1.1 protocol=icmp \
    src-address=192.168.10.0/24
add action=drop chain=forward comment="DROP all other inter-VLAN"
/ip route
add comment="Default via pfSense" dst-address=0.0.0.0/0 gateway=192.168.1.1
/system identity
set name=mikrotik-pfe
/system note
set show-at-login=no
/system ntp client
set enabled=yes
/system ntp client servers
add address=216.239.35.0
/tool sniffer
set filter-interface=bridge-dmz filter-stream=yes
