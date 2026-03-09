# 🔐 PFE — Sécurisation des Flux de Communication pour un Écosystème IoT Simulé

> **Faculté des Sciences de Tunis (FST)** | Année universitaire 2025–2026

## 👥 Encadrement

| Rôle | Nom |
|------|-----|
| Encadrante universitaire | Mme. ELLOUZE NOURHENE — FST |
| Encadrant entreprise | M. Moez Khlifi — Tunisie Telecom (TT) |
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

Projet académique — FST / Tunisie Telecom © 2026