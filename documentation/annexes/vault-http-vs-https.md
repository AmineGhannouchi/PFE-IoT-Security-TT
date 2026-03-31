# Vault CLI — HTTP vs HTTPS

## Problème
Le listener Vault est en HTTP (tls_disable=true), mais le CLI essaye par défaut d’utiliser HTTPS.

## Correction
Définir VAULT_ADDR en http:// :
- Exemple : VAULT_ADDR=http://127.0.0.1:8200

## Impact
Permet d'exécuter `vault status/init/unseal` sans erreur.