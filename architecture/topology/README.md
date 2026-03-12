# Topologie GNS3 — PFE IoT Security TT

## Fichier projet
- `PFE-IoT-Security-TT.gns3project` — Projet GNS3 exportable

## Prérequis pour ouvrir
- GNS3 version 2.2.x
- VMware Workstation Player
- Images QEMU :
  - pfSense CE 2.7.x
  - MikroTik CHR 7.x

## Composants simulés
| Composant | RAM | vCPU | Rôle |
|-----------|-----|------|------|
| pfSense CE | 512 Mo | 1 | Firewall / NAT / Routeur |
| MikroTik CHR | 256 Mo | 1 | Switch L3 / VLAN / ACL |

## Plan d'adressage
Voir `plan-adressage.md`

## Démarrage
1. Démarrer GNS3 VM dans VMware
2. Ouvrir GNS3 Desktop
3. Ouvrir ce projet
4. Start All Nodes
5. Attendre ~3 min (boot pfSense)
6. Vérifier les consoles