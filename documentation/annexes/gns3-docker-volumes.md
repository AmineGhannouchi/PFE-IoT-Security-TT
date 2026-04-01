# Persistance Docker Nodes dans GNS3 (container paths only)

## Constat
GNS3 n'accepte pas les bind mounts `host_path:container_path` dans ce lab.

## Solution
Utilisation de volumes gérés par Docker via chemins conteneur uniquement :
- Vault : /vault/data, /vault/logs, /vault/init, /vault/config
- Toolbox : /work

## Validation
- /work/persist.txt conservé après redémarrage node
- Vault initialized=true après redémarrage (sealed=true attendu)