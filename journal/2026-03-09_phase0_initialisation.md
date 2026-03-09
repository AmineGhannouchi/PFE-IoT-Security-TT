# Journal Technique — 2026-03-09

## Phase 0 : Initialisation du projet

### Informations générales

| Champ | Valeur |
|-------|--------|
| Date | 2026-03-09 |
| Étudiant | Amine Ghannouchi |
| Encadrante universitaire | Mme. Ellouze Nourhène (FST) |
| Encadrant entreprise | M. Moez Khlifi (Tunisie Telecom) |
| OS hôte | Windows 11 |
| CPU | Intel Core i3-1215U |
| RAM | 16 Go |
| Repository | https://github.com/AmineGhannouchi/PFE-IoT-Security-TT |

### Décisions d'Architecture Initiales

| Décision | Choix | Justification |
|----------|-------|--------------|
| Simulation réseau | GNS3 | Standard industrie, support pfSense + MikroTik |
| Virtualisation | VMware Workstation | Compatibilité Windows 11, support GNS3 |
| Conteneurisation | Docker Desktop | Facilité de déploiement, isolation |
| Firewall simulé | pfSense CE | Open source, fonctionnalités IDS/VPN |
| Routeur simulé | MikroTik CHR | Léger, fonctionnel pour simulation |
| Broker MQTT | Mosquitto + EMQX | Comparatif TLS/mTLS |
| PKI | HashiCorp Vault | Gestion dynamique des certificats |
| SIEM | Wazuh + OpenSearch | Stack open source robuste |
| IDS/IPS | Suricata | Performances, règles communautaires |
| Analyse réseau | Zeek | Logs structurés, scripting puissant |
| ML | scikit-learn | IsolationForest + RandomForest |

### Actions Effectuées

- [x] Création du repository GitHub `PFE-IoT-Security-TT`
- [x] Initialisation de la structure de dossiers
- [x] Création du README.md professionnel
- [x] Création du journal technique
- [x] Ajout du .gitignore
- [x] Création du plan du rapport
- [x] Premier diagramme PlantUML (architecture globale)

### Prochaine Étape

**Phase 1** : Conception détaillée de l'architecture
- Topologie réseau GNS3 détaillée
- Diagrammes de flux E2E
- Diagrammes de séquence par protocole
- Tableau comparatif des solutions techniques
