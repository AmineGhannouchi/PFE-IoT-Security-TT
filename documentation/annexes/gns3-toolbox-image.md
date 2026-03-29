# Image pfe-toolbox pour GNS3 (Docker engine GNS3 VM)

## But
Éviter l'installation runtime `apk add` (Internet instable) en fournissant une image pré-équipée.

## Contenu
curl, openssl, bind-tools, tcpdump, nmap, python3, jq, etc.

## Build (dans GNS3 VM)
docker build -t pfe-toolbox:1.0 .

## Utilisation
Créer un template Docker GNS3 puis déployer `toolbox-pki` en zone PKI.