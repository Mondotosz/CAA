# file: foo.hcl
# Allow read of anything within secret/foo
path "secret/foo/*" {
  capabilities = ["read"]
}

# Allow read and update for secret/bar
path "secret/bar" {
  capabilities = ["read", "update"]
}
