# 🔐 PFE — Sécurisation des Flux de Communication pour un Écosystème IoT Simulé

> **Faculté des Sciences de Tunis (FST)** | Année universitaire 2025–2026

## 👥 Encadrement

| Rôle | Nom |
|------|-----|
| Encadrante universitaire | Mme. ELLOUZE NOURHENE — FST |
| Encadrant entreprise | M. Moez Khlif — Tunisie Telecom (TT) |
| Étudiant | Amine Ghannouchi |

## 📌 Contexte

Ce projet de fin d'études (PFE) est réalisé en partenariat avec **Tunisie Telecom (TT)**.
Il vise à concevoir, implémenter et évaluer une architecture IoT sécurisée End-to-End (E2E)
dans un environnement simulé, répondant aux problématiques de sécurité rencontrées par les
opérateurs télécom dans la gestion de leurs flux IoT massifs et hétérogènes.

## 🎯 Objectifs

- Sécuriser les communications IoT (MQTT, CoAP, HTTP) via TLS 1.3 / mTLS / DTLS
- Mettre en place une PKI robuste avec HashiCorp Vault
- Déployer un SIEM (Wazuh + OpenSearch) pour la supervision et corrélation d'événements
- Implémenter la détection d'anomalies par Machine Learning (IsolationForest, RandomForest)
- Évaluer l'impact des mécanismes de sécurité sur les performances

## 🏗️ Stack Technique

| Couche | Composants |
|--------|-----------|
| Simulation réseau | GNS3, pfSense CE, MikroTik CHR |
| Infrastructure | Docker, Docker Compose, VMware/QEMU |
| Protocoles IoT | MQTT (Mosquitto/EMQX), CoAP (aiocoap), HTTP |
| Sécurité | TLS 1.3, mTLS, DTLS, PKI (HashiCorp Vault), OpenSSL |
| Analyse réseau | Suricata, Zeek, Wireshark, tcpdump |
| SIEM | Wazuh, OpenSearch, OpenSearch Dashboards |
| ML / Anomalies | Python, pandas, scikit-learn, IsolationForest, RandomForest |
| Tests de charge | paho-benchmark, JMeter |

## 📁 Structure du Projet

```
PFE-IoT-Security-TT/
├── architecture/       # Diagrammes et topologie
├── infrastructure/     # Docker, VM, Ansible
├── pki/                # HashiCorp Vault, certificats, scripts OpenSSL
├── iot/                # Devices simulés, gateway, broker
├── security/           # Suricata, Zeek, configs TLS
├── siem/               # Wazuh, OpenSearch
├── datasets/           # Données capturées
├── ml/                 # Notebooks et modèles ML
├── tests/              # Tests performance, attaques, scénarios
├── scripts/            # Scripts utilitaires
├── results/            # Résultats expérimentaux
├── documentation/      # Rapport LaTeX, annexes
└── journal/            # Journal technique
```

## 📖 Journal Technique

Voir [JOURNAL.md](./JOURNAL.md) pour le suivi des décisions, commandes et résultats.

## 🚀 Démarrage Rapide

```bash
git clone https://github.com/AmineGhannouchi/PFE-IoT-Security-TT.git
cd PFE-IoT-Security-TT
```

## 📄 Licence

## 📝 Entrées

### 2026-03-09 — Phase 0 : Initialisation du projet

**Décision** : Création et structuration du repository GitHub `PFE-IoT-Security-TT`.

**Actions réalisées** :
- Clonage du repository existant
- Création de la structure de dossiers complète (28 répertoires)
- Rédaction du README.md avec contexte FST/TT
- Création du .gitignore adapté
- Premier commit structurel

**Résultat** : Structure de base opérationnelle, prête pour les phases suivantes.

**Contraintes identifiées** :
- Machine : Windows 11, i3-1215U, 16 Go RAM
- Stratégie d'optimisation requise pour GNS3 + Docker simultanément

**Solution** : Architecture allégée — pas de VMs lourdes simultanées,
utilisation maximale de Docker, GNS3 en mode léger (Docker nodes).

---

### 2026-03-09 — Phase 1 : Conception de l'Architecture

**Décisions d'architecture** :
- 5 zones de sécurité : IoT (VLAN10), DMZ (VLAN20), PKI (VLAN30),
  SIEM (VLAN40), Analyse (VLAN50)
- Broker MQTT retenu : Mosquitto (léger, open source, TLS/mTLS)
- Infrastructure : Docker Compose pour tous les services applicatifs
- Réseau simulé : GNS3 VM (pfSense + MikroTik CHR)
- PKI : HashiCorp Vault en mode PKI Engine
- SIEM : Wazuh single-node + OpenSearch 1 nœud (contrainte RAM)

**Artefacts produits** :
- 4 diagrammes PlantUML (architecture, topologie, flux E2E, composants)
- Plan d'adressage IP complet (6 VLANs)
- Tableau comparatif brokers MQTT

**Contraintes identifiées** :
- 16 Go RAM → services lancés de manière séquentielle/groupée
- GNS3 VM limitée à 4 Go RAM
- Docker Desktop limité à 10 Go RAM

### 2026-03-16 — Phase 3bis : Centralisation Docker dans GNS3

**Décision** : Utiliser Docker Engine de la GNS3 VM et exécuter les services (PKI, Broker, SIEM, IDS) comme nœuds Docker dans GNS3.

**Motivation** :
- Centraliser simulation réseau + services applicatifs
- Simplifier l’observabilité des flux dans la topologie
- Faciliter les démonstrations (start/stop des services dans GNS3)

**Implémentation** :
- Création de 5 switches (SW-IOT, SW-DMZ, SW-PKI, SW-SIEM, SW-ANALYSE)
- Ajout de 5 conteneurs Alpine test, IP statiques par zone
- Tests ping passerelles + validation segmentation IoT→SIEM/Analyse bloquée

**Résultat** : Docker nodes gérés par GNS3, connectivité inter-zones conforme.

### 2026-03-28 — Phase 3bis : Docker dans GNS3 + Debug routage pfSense

**Contexte** : Les conteneurs Alpine sont exécutés comme Docker nodes dans GNS3 (Docker engine = GNS3 VM).

**Problème** : Depuis `alpine-iot` (192.168.10.100), ping vers `192.168.10.1` OK (GW MikroTik), mais ping vers `pfSense LAN 192.168.1.1` KO.

**Analyse** :
- Routage correct côté MikroTik (default route vers 192.168.1.1)
- Routes statiques ajoutées sur pfSense
- Le blocage provenait du firewall MikroTik (chain=forward) sur ICMP.

**Solution appliquée** :
Ajout règle MikroTik autorisant ICMP IoT → pfSense :
`/ip firewall filter add chain=forward action=accept protocol=icmp src-address=192.168.10.0/24 dst-address=192.168.1.1 comment="ALLOW ICMP IoT -> pfSense (debug)"`

**Résultat** :
- Ping IoT → pfSense OK
- Segmentation inter-zones conservée

### 2026-03-28 — Phase 4 : Persistance GNS3 Docker nodes

**Problème** : Les données `/work/vault` dans pfe-toolbox disparaissaient après redémarrage GNS3.

**Cause** : Conteneurs Docker GNS3 sans volume persistant.

**Solution** :
- Activation de volumes GNS3 “container-path only”
- Toolbox : persister `/work`
- Vault : persister `/vault/data`, `/vault/logs`, `/vault/init`, `/vault/config`

**Résultat** :
- Données toolbox conservées
- Vault conserve son état (initialized=true) après reboot, unseal requis.