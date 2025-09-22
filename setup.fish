#!/usr/bin/env fish

# Prompt the user for the root token.
# NOTE: This requires gum to be installed
set -l root_token (gum input --password --prompt="root token: " --placeholder "s.xxxxxxxxxxxxxxxxxxxxxxxx")
set -x BAO_ADDR http://localhost:8200

# Authenticate with the cli
bao login $root_token

# Enable required engines
bao secrets enable kv-v2
bao secrets enable transit
