#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}

echo "[*] Waiting for Vault to be ready at $VAULT_ADDR..."
until curl -sf "$VAULT_ADDR/v1/sys/health" >/dev/null; do sleep 2; done

if [ ! -f ./vault/unseal.json ]; then
  echo "[*] Initializing Vault..."
  init_out=$(curl -sf --request POST --data '{"secret_shares":1,"secret_threshold":1}' "$VAULT_ADDR/v1/sys/init")
  echo "$init_out" | jq . > ./vault/unseal.json
  UNSEAL_KEY=$(echo "$init_out" | jq -r .keys_base64[0])
  ROOT_TOKEN=$(echo "$init_out" | jq -r .root_token)
  echo "[*] Unsealing Vault..."
  curl -sf --request POST --data "{\"key\":\"$UNSEAL_KEY\"}" "$VAULT_ADDR/v1/sys/unseal" >/dev/null
else
  echo "[*] Using existing ./vault/unseal.json"
  UNSEAL_KEY=$(jq -r .keys_base64[0] ./vault/unseal.json)
  ROOT_TOKEN=$(jq -r .root_token ./vault/unseal.json)
  curl -sf --request POST --data "{\"key\":\"$UNSEAL_KEY\"}" "$VAULT_ADDR/v1/sys/unseal" >/dev/null || true
fi

echo "[*] Enabling KV v2 at secret/ ..."
curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  --request POST \
  --data '{"type":"kv","options":{"version":"2"}}' \
  "$VAULT_ADDR/v1/sys/mounts/secret" >/dev/null || true

echo "[*] Writing sample Jenkins secret..."
curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  --request POST \
  --data '{"data":{"docker_user":"example","docker_pass":"change_me"}}' \
  "$VAULT_ADDR/v1/secret/data/jenkins/dockerhub" >/dev/null

echo "[*] Creating Jenkins policy..."
cat > ./vault/jenkins-policy.hcl <<'POLICY'
path "secret/data/jenkins/*" {
  capabilities = ["read"]
}
POLICY

curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  --request PUT \
  --data @./vault/jenkins-policy.hcl \
  "$VAULT_ADDR/v1/sys/policies/acl/jenkins" >/dev/null

echo "[*] Enabling AppRole auth..."
curl -sf --header "X-Vault-Token: $ROOT_TOKEN" --request POST "$VAULT_ADDR/v1/sys/auth/approle" --data '{"type":"approle"}' >/dev/null || true

echo "[*] Creating Jenkins AppRole..."
curl -sf --header "X-Vault-Token: $ROOT_TOKEN" --request POST "$VAULT_ADDR/v1/auth/approle/role/jenkins" --data '{"policies":"jenkins","token_ttl":"1h","token_max_ttl":"4h"}' >/dev/null

ROLE_ID=$(curl -sf --header "X-Vault-Token: $ROOT_TOKEN" "$VAULT_ADDR/v1/auth/approle/role/jenkins/role-id" | jq -r .data.role_id)
SECRET_ID=$(curl -sf --header "X-Vault-Token: $ROOT_TOKEN" --request POST "$VAULT_ADDR/v1/auth/approle/role/jenkins/secret-id" | jq -r .data.secret_id)

cat > ./vault/jenkins-approle.json <<JSON
{
  "VAULT_ADDR": "$VAULT_ADDR",
  "ROLE_ID": "$ROLE_ID",
  "SECRET_ID": "$SECRET_ID"
}
JSON

echo "[✓] Vault is initialized and unsealed. Jenkins AppRole created."
echo "    Details: ./vault/unseal.json and ./vault/jenkins-approle.json"

