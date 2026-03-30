storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

ui = true
disable_mlock = true

# IP du node Vault dans GNS3
api_addr     = "http://192.168.30.10:8200"
cluster_addr = "http://192.168.30.10:8201"