ui = true
disable_mlock = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# Enable audit logging
audit {
  enabled = true
  path    = "file"
  options = {
    file_path = "/vault/logs/audit.log"
  }
}

# Enable metrics
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = false
}

# Seal configuration for production
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/vault-key"
}

# High availability (if needed)
# storage "consul" {
#   address = "127.0.0.1:8500"
#   path    = "vault/"
# }

# Auto-unseal (for development only)
# seal "transit" {
#   address = "http://127.0.0.1:8200"
#   disable_renewal = "false"
#   key_name = "autounseal"
#   mount_path = "transit/"
# }

