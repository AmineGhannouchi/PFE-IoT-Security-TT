# ================================================
# HashiCorp Vault — Configuration PFE IoT Security
# ================================================

# Stockage des données (fichier local pour dev/PFE)
storage "file" {
  path = "/vault/data"
}

# Listener HTTP (TLS désactivé pour init,
# sera activé après provisionnement des certs)
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = true
}

# Interface API
api_addr     = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"

# Interface UI activée
ui = true

# Logs
log_level  = "info"
log_file   = "/vault/logs/vault.log"

# Désactiver mlock (requis dans Docker)
disable_mlock = true

# Durée de session maximale
max_lease_ttl         = "87600h"   # 10 ans (Root CA)
default_lease_ttl     = "8760h"    # 1 an (certificats services)