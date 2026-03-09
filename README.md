# 🔐 PFE — Sécurisation des Flux de Communication pour un Écosystème IoT Simulé

<p align="center">
  <img src="https://img.shields.io/badge/Status-En%20cours-blue?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Protocoles-MQTT%20%7C%20CoAP%20%7C%20HTTP-green?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/Sécurité-TLS%20%7C%20mTLS%20%7C%20DTLS-red?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/SIEM-Wazuh%20%7C%20OpenSearch-orange?style=for-the-badge"/>
</p>

---

## 📌 Contexte

Ce projet de fin d'études (PFE) vise à concevoir, implémenter et évaluer une **architecture IoT sécurisée End-to-End (E2E)** dans un environnement simulé.

Il répond aux problématiques de sécurité rencontrées par les opérateurs télécom (Tunisie Telecom) dans la gestion de leurs flux IoT massifs et hétérogènes.

---

## 🎯 Objectifs

- 🔒 Sécuriser les communications IoT (MQTT, CoAP, HTTP) via **TLS 1.3 / mTLS / DTLS**
- 🏛️ Mettre en place une **PKI robuste** avec HashiCorp Vault
- 📊 Déployer un **SIEM** (Wazuh + OpenSearch) pour la supervision
- 🤖 Implémenter la **détection d'anomalies** par Machine Learning
- ⚡ Évaluer l'**impact des mécanismes de sécurité** sur les performances

---

## 🏗️ Architecture Technique

| Couche | Composants |
|--------|-----------|
| Simulation réseau | GNS3, pfSense CE, MikroTik CHR |
| Infrastructure | Docker, Docker Compose, VMware Workstation |
| Protocoles IoT | MQTT, CoAP, HTTP |
| Sécurité | TLS 1.3, mTLS, DTLS, PKI (HashiCorp Vault) |
| Analyse réseau | Suricata, Zeek, Wireshark, tcpdump |
| SIEM | Wazuh, OpenSearch, OpenSearch Dashboards |
| ML / IA | Python, scikit-learn, IsolationForest, RandomForest |
| Tests | paho-benchmark, JMeter, tc/netem |

---

## 📁 Structure du Projet

```
PFE-IoT-Security-TT/
├── architecture/       # Diagrammes, PlantUML, topologie GNS3
├── infrastructure/     # Docker, Ansible, VM provisioning
├── pki/                # HashiCorp Vault, certificats, scripts OpenSSL
├── iot/                # Devices simulés, gateway, broker MQTT
├── security/           # Suricata, Zeek, configs TLS
├── siem/               # Wazuh, OpenSearch
├── datasets/           # Captures réseau, logs, CSV
├── ml/                 # Notebooks Jupyter, modèles ML
├── tests/              # Tests performance, attaques, scénarios
├── scripts/            # Scripts utilitaires
├── results/            # Résultats expérimentaux
├── documentation/      # Rapport LaTeX, annexes
└── journal/            # Journal technique
```

---

## 🚀 Démarrage Rapide

```bash
git clone https://github.com/AmineGhannouchi/PFE-IoT-Security-TT.git
cd PFE-IoT-Security-TT
```

---

## 📖 Journal Technique

Voir [JOURNAL.md](./JOURNAL.md) pour le suivi détaillé des décisions techniques et expérimentations.

---

## 👥 Équipe

| Rôle | Nom |
|------|-----|
| 🎓 Étudiant | Amine Ghannouchi |
| 👩‍🏫 Encadrante universitaire | Mme. Ellouze Nourhène |
| 👨‍💼 Encadrant entreprise | M. Moez Khlifi |
| 🏫 Établissement | FST — Faculté des Sciences de Tunis |
| 🏢 Entreprise d'accueil | Tunisie Telecom |
| 📅 Année | 2025 — 2026 |

---

## 📄 Licence

Projet académique — usage interne PFE uniquement.