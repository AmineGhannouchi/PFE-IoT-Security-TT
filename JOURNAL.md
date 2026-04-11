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

---

### 2026-04-11 — Étape 1 : Audit Vault + Correction Persistance

**Problème critique identifié** :
- `docker-compose.pki.yml` référençait `pki/vault/config/` (inexistant) et `init-vault.sh` (manquant).
- Données Vault perdues après redémarrage GNS3 : pas de volume Docker sur `/vault/data`.

**Solutions implémentées** :

1. **Créé `pki/vault/config/vault.hcl`** — Config Vault pour le déploiement Docker Compose
   (storage=file:/vault/data, listener TCP 0.0.0.0:8200, TLS désactivé en PKI interne)

2. **Créé `pki/vault/scripts/init-vault.sh`** — Script d'initialisation idempotent :
   - Attend que Vault soit accessible (30 tentatives × 3s)
   - Initialise (5 shares / threshold 3) si pas encore fait
   - Sauvegarde unseal keys + root token dans `/vault/init/` (volume persistant)
   - Déscelle automatiquement avec 3 clés
   - Lance `bootstrap-pki-api.sh` (PKI root CA + intermediate CA + rôles)

3. **Corrigé `infrastructure/docker/docker-compose.pki.yml`** :
   - Healthcheck robuste via `/v1/sys/health`
   - Service `vault-init` exécute `init-vault.sh` (restart=no, après healthcheck)
   - 3 volumes nommés : `pfe-vault-data`, `pfe-vault-logs`, `pfe-vault-init-data`

4. **Corrigé `pki/vault/scripts/bootstrap-pki-api.sh`** et **`issue-mosquitto-cert-api.sh`** :
   - Support des deux formats de token (`VAULT_ROOT_TOKEN=xxx` et token brut)
   - `VAULT_ADDR` et `ROOT_TOKEN_FILE` configurables via env var

5. **Créé `scripts/audit-vault.sh`** — Audit complet :
   - Ping + port PKI zone
   - /v1/sys/health avec diagnostic HTTP code
   - Vérification moteurs PKI (pki, pki_int)
   - Test émission certificat
   - Vérification rôles (iot-services, iot-devices)

6. **Créé `tests/scenarios/test-vault-api.sh`** — Tests automatisés Vault API

**Validation** :
```bash
# Démarrer la stack PKI
docker compose -f infrastructure/docker/docker-compose.pki.yml up -d

# Audit depuis toolbox
docker exec pfe-toolbox sh /scripts/audit-vault.sh

# Tests automatisés
bash tests/scenarios/test-vault-api.sh http://192.168.30.10:8200
```

**Résultat attendu** : `Vault 100% opérationnel — passage à MQTT autorisé.`

---

### 2026-04-11 — Étape 2 : Déploiement Mosquitto TLS/mTLS

**Artefacts créés** :

1. **`infrastructure/docker/docker-compose.mosquitto.yml`** :
   - Service `mosquitto` (eclipse-mosquitto:2.0) sur DMZ 192.168.20.10:8883
   - Service `mosquitto-cert-init` : récupère les certs depuis Vault avant démarrage
   - Volumes : `pfe-mosquitto-certs`, `pfe-mosquitto-data`, `pfe-mosquitto-logs`
   - Réseau : `pfe-dmz-network` (externe)

2. **`iot/broker/mosquitto-gns3/Dockerfile`** mis à jour :
   - Suppression du `COPY certs/` — les certs viennent du volume (jamais dans l'image)
   - Création propre des répertoires data/log avec permissions mosquitto

**Procédure de déploiement** :
```bash
# 1. S'assurer que PKI est prête
bash tests/scenarios/test-vault-api.sh http://192.168.30.10:8200

# 2. Démarrer la stack Mosquitto
docker compose -f infrastructure/docker/docker-compose.mosquitto.yml up -d

# 3. Test connexion mTLS depuis pfe-toolbox
mosquitto_pub \
  --cafile /work/vault/certs/ca-chain.crt \
  --cert   /work/fleet-sim/certs/<device_id>/client.crt \
  --key    /work/fleet-sim/certs/<device_id>/client.key \
  -h 192.168.20.10 -p 8883 \
  -t iot/test/hello -m '{"msg":"ok"}' --tls-version tlsv1.3
```

**Avancement global** : 45%

Prochaine étape : Simulation IoT fleet (fleet_sim.py) + IDS (Suricata/Zeek).