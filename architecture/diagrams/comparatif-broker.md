# Comparatif Brokers MQTT

| Critère | Mosquitto | EMQX | HiveMQ | VerneMQ |
|---------|-----------|------|--------|---------|
| Licence | Open Source | Open Source (CE) | Commercial | Open Source |
| TLS/mTLS | ✅ | ✅ | ✅ | ✅ |
| Auth X.509 | ✅ | ✅ | ✅ | ✅ |
| MQTT 5.0 | ✅ | ✅ | ✅ | ✅ |
| Scalabilité | Faible | Très haute | Haute | Haute |
| RAM requise | ~50 Mo | ~500 Mo | ~512 Mo | ~256 Mo |
| Docker | ✅ | ✅ | ✅ | ✅ |
| Dashboard UI | ❌ | ✅ | ✅ | ❌ |
| Adapté PFE (16 Go) | ✅✅ | ✅ | ⚠️ | ✅ |

**→ Choix retenu : Mosquitto** (léger, open source, supporte TLS/mTLS, parfait pour 16 Go RAM)