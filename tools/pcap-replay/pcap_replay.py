#!/usr/bin/env python3
"""
PFE IoT Security TT — Rejeu de capture réseau (pcap) pour la chaîne de détection.

Rejoue les trames d'un fichier .pcap / .pcapng sur une interface réseau afin
que Suricata (zone Analyse) les ré-analyse et génère des alertes -> Wazuh.

Deux modes :
  - Auto (démo)   : attend N secondes (60 par défaut) puis envoie le flux une fois.
                    Lancé automatiquement au démarrage via le service systemd.
  - Manuel        : option --now pour envoyer immédiatement (commande précise).

Exemples :
  sudo python3 pcap_replay.py --now --iface eth0
  sudo python3 pcap_replay.py --delay 60 --iface eth0 --loops 3
"""

import argparse
import logging
import sys
import time

try:
    from scapy.all import rdpcap, sendp
except ImportError:
    sys.stderr.write("[ERREUR] scapy n'est pas installé. Faire : pip3 install scapy\n")
    sys.exit(1)


def parse_args():
    p = argparse.ArgumentParser(description="Rejeu pcap vers Suricata (PFE IoT Security TT)")
    p.add_argument("--pcap", default="/opt/pfe/wireshark.pcapng",
                   help="Chemin du fichier pcap/pcapng (défaut: /opt/pfe/wireshark.pcapng)")
    p.add_argument("--iface", default="eth0",
                   help="Interface d'émission, reliée au segment surveillé par Suricata (défaut: eth0)")
    p.add_argument("--delay", type=int, default=60,
                   help="Délai en secondes avant l'envoi (défaut: 60)")
    p.add_argument("--now", action="store_true",
                   help="Envoie immédiatement (ignore --delay)")
    p.add_argument("--loops", type=int, default=1,
                   help="Nombre de répétitions du flux (défaut: 1)")
    p.add_argument("--inter", type=float, default=0.0,
                   help="Pause en secondes entre chaque paquet (défaut: 0 = pleine vitesse)")
    return p.parse_args()


def main():
    args = parse_args()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    log = logging.getLogger("pcap-replay")

    delay = 0 if args.now else args.delay
    if delay > 0:
        log.info("Attente de %ds avant l'envoi du flux...", delay)
        time.sleep(delay)

    log.info("Lecture du pcap : %s", args.pcap)
    try:
        packets = rdpcap(args.pcap)
    except FileNotFoundError:
        log.error("Fichier introuvable : %s", args.pcap)
        sys.exit(1)
    except Exception as exc:  # pcap corrompu, format non supporté, etc.
        log.error("Lecture impossible (%s) : %s", args.pcap, exc)
        sys.exit(1)

    total = len(packets)
    log.info("%d paquets chargés. Émission sur %s (loops=%d, inter=%.3fs)",
             total, args.iface, args.loops, args.inter)

    for i in range(1, args.loops + 1):
        try:
            sendp(packets, iface=args.iface, inter=args.inter, verbose=False)
        except PermissionError:
            log.error("Permission refusée : lancer en root (raw socket).")
            sys.exit(1)
        except OSError as exc:
            log.error("Erreur réseau sur %s : %s", args.iface, exc)
            sys.exit(1)
        log.info("Boucle %d/%d envoyée (%d paquets)", i, args.loops, total)

    log.info("Rejeu terminé.")


if __name__ == "__main__":
    main()
