Jenkins ↔ Vault (AppRole) quick setup

1) Start Vault on Server 1

- Ensure compose is up with the `vault` service:
  - `docker compose -f docker-compose.hub.yml --profile secrets up -d vault`

2) Initialize and create Jenkins AppRole

- `chmod +x vault/init-jenkins.sh && vault/init-jenkins.sh`
- Outputs:
  - `vault/unseal.json` (unseal key and root token) – keep private
  - `vault/jenkins-approle.json` (VAULT_ADDR, ROLE_ID, SECRET_ID)

3) Install Jenkins Vault Plugin

- Manage Jenkins → Plugins → Available → install "HashiCorp Vault" plugin
- Manage Jenkins → Credentials → System → Global → Add Credentials:
  - Kind: "Vault App Role Credential"
  - Role ID: from `jenkins-approle.json`
  - Secret ID: from `jenkins-approle.json`
  - ID: `vault-approle`

4) Configure Jenkins Global Vault

- Manage Jenkins → System → HashiCorp Vault Plugin:
  - Vault URL: `http://185.252.234.29:8200`
  - Credentials: `vault-approle`
  - Engine Version: `2`

5) Use in Pipeline (example)

```groovy
pipeline {
  agent any
  stages {
    stage('Use secrets') {
      steps {
        withVault([vaultSecrets: [[path: 'secret/data/jenkins/dockerhub', secretValues: [
          [envVar: 'DOCKER_USER', vaultKey: 'docker_user'],
          [envVar: 'DOCKER_PASS', vaultKey: 'docker_pass']
        ]]]]) {
          sh 'echo Using $DOCKER_USER'
        }
      }
    }
  }
}
```

Notes

- Vault is running without TLS for simplicity; restrict network access or place behind VPN. For TLS, terminate with a reverse proxy or configure Vault TLS.
- Rotate SecretID periodically (Jenkins credential update required).
- To add more secrets: `secret/data/jenkins/<name>` with KV v2 schema `{data: {...}}`.

