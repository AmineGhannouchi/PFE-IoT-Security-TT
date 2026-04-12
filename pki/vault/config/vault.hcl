# ================================================
# HashiCorp Vault — Configuration PKI
# PFE IoT Security TT
# ================================================

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

ui            = true
disable_mlock = true
log_level     = "info"

api_addr     = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"
