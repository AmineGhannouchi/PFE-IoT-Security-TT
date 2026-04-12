#sudo bash infrastructure/docker/deploy-wazuh-gns3.sh 
#docker compose -f docker-compose.wazuh.yml ps

docker exec -it docker-wazuh.indexer-1 bash -c \
  'export JAVA_HOME=/usr/share/wazuh-indexer/jdk && \
   bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
   -cd /usr/share/wazuh-indexer/opensearch-security/ \
   -nhnv \
   -cacert /usr/share/wazuh-indexer/certs/root-ca.pem \
   -cert /usr/share/wazuh-indexer/certs/admin.pem \
   -key /usr/share/wazuh-indexer/certs/admin-key.pem \
   -h localhost \
   -icl'