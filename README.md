# 🔐 PFE — Sécurisation des Flux de Communication pour un Écosystème IoT Simulé

## 📌 Contexte

Ce projet de fin d'études (PFE) vise à concevoir, implémenter et évaluer une architecture
IoT sécurisée End-to-End (E2E) dans un environnement simulé. Il répond aux problématiques
de sécurité rencontrées par les opérateurs télécom dans la gestion de leurs flux IoT.

## 🎯 Objectifs

- Sécuriser les communications IoT (MQTT, CoAP, HTTP) via TLS/mTLS/DTLS
- Mettre en place une PKI robuste avec HashiCorp Vault
- Déployer un SIEM (Wazuh + OpenSearch) pour la supervision
- Implémenter la détection d'anomalies par Machine Learning
- Évaluer l'impact des mécanismes de sécurité sur les performances

## 🏗️ Architecture Technique

| Couche | Composants |
|--------|-----------|
| Simulation réseau | GNS3, pfSense, MikroTik CHR |
| Infrastructure | Docker, Docker Compose, VMware/QEMU |
| Protocoles IoT | MQTT, CoAP, HTTP |
| Sécurité | TLS 1.3, mTLS, DTLS, PKI (Vault) |
| Analyse réseau | Suricata, Zeek, Wireshark |
| SIEM | Wazuh, OpenSearch, Dashboards |
| ML | Python, scikit-learn, IsolationForest |

## 📁 Structure du Projet

Voir `documentation/` pour l'arborescence détaillée.

## 🚀 Démarrage Rapide

```bash
git clone https://github.com/<username>/PFE-IoT-Security.git
cd PFE-IoT-Security
```

## 📖 Journal Technique

Voir [JOURNAL.md](./JOURNAL.md) pour le suivi des décisions et expérimentations.

## 👤 Auteur

- **Étudiant** : Amine Ghannouchi
- **Encadrant** : [À compléter]
- **Établissement** : [À compléter]
- **Année** : 2025-2026