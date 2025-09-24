# Allow access to the metadata in Financial and IT
path "kv-v2/metadata/ciphertexts/Financial/*" {
  capabilities = ["list"]
}

path "kv-v2/metadata/ciphertexts/IT/*" {
  capabilities = ["list"]
}

path "kv-v2/detailed-metadata/ciphertexts/Financial/*" {
  capabilities = ["list"]
}

path "kv-v2/detailed-metadata/ciphertexts/IT/*" {
  capabilities = ["list"]
}
