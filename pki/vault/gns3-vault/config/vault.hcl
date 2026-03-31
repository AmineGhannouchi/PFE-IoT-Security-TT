storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

ui = true
disable_mlock = true

# On ne force pas api_addr à une IP fixe ici (GNS3 gère ton IP),
# sinon ça peut créer des problèmes si tu changes l'IP.
api_addr = "http://0.0.0.0:8200"