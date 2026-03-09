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