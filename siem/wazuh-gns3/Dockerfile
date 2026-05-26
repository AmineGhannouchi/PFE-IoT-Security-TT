# =====================================================
# Wazuh Manager — Docker GNS3
# Zone SIEM : 192.168.40.10 (VLAN 40)
# PFE IoT Security TT
# Configuration via interface web apres demarrage
# =====================================================
FROM wazuh/wazuh-manager:4.9.2

# Configuration IP automatique au démarrage — Zone SIEM 192.168.40.10
RUN printf '#!/bin/sh\nip addr add 192.168.40.10/24 dev eth0 2>/dev/null || true\nip route add default via 192.168.40.1 2>/dev/null || true\necho "[wazuh-net] IP 192.168.40.10/24 configuree"\n' \
    > /etc/cont-init.d/00-network.sh && chmod +x /etc/cont-init.d/00-network.sh

EXPOSE 514/udp
EXPOSE 1514/tcp
EXPOSE 1515/tcp
EXPOSE 55000/tcp
