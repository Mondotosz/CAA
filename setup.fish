#!/usr/bin/env fish
# Check requirements
set missing_requirement false

if type -q rgg
    set grep rg
else if type -q grep
    set grep grep
else
    echo "grep or ripgrep are required"
    echo "https://github.com/BurntSushi/ripgrep"
    set missing_requirement true
end

if not type -q gum
    echo "gum is required"
    echo "https://github.com/charmbracelet/gum"
    set missing_requirement true
end

if not type -q docker
    echo "docker is required"
    echo "https://www.docker.com/"
    set missing_requirement true
end

if not type -q bao
    echo "bao is required"
    echo "https://openbao.org/docs/install/"
    set missing_requirement true
end

if test $missing_requirement = true
    return 1
end

set -l root_path (dirname (status --current-filename))

# Styles
set -x PADDING "0 1"
set -x BORDER rounded
set -x BOLD true

set -x tasks docker auth engines groups policies users watcher

set -x selected (gum choose --no-limit --header "Actions (choose what to apply)" $tasks --selected "*")

if contains docker in $selected
    gum style Docker
    docker compose --project-directory $root_path up -d --wait
    set root_token (docker compose --project-directory $root_path logs \
        | $grep -o "Root Token: s\.\S+" \
        | tail -n 1 \
        | string replace "Root Token: " "")
    echo "Root Token: $root_token"
end

if contains auth in $selected
    gum style Auth
    # Prompt the user for the root token.
    if not set -q root_token
        set root_token (gum input --password --prompt="root token: " --placeholder "s.xxxxxxxxxxxxxxxxxxxxxxxx")
    end
    set -x BAO_ADDR http://localhost:8200

    # Authenticate with the cli
    bao login $root_token
end

if contains engines in $selected
    gum style Engines
    # Enable required engines
    bao secrets enable kv-v2
    bao secrets enable transit
end

if contains groups in $selected
    gum style Groups
    bao write -f transit/keys/Financial type=aes256-gcm96 auto_rotate_period=1h
    bao write -f transit/keys/IT type=chacha20-poly1305 auto_rotate_period=1h
end

if contains policies in $selected
    gum style Policies
    bao policy write it $root_path/policies/IT.hcl
    bao policy write financial $root_path/policies/Financial.hcl
end

if contains users in $selected
    gum style Users
    bao auth enable userpass
    bao write auth/userpass/users/ceo password=ceo1 policies="it,financial"
    bao write auth/userpass/users/bob password=bob1 policies="it"
    bao write auth/userpass/users/secretary password=secretary1 policies="financial"
end

if contains watcher in $selected
    gum style Users
    bao policy write watcher $root_path/policies/Watcher.hcl
    bao token create -policy watcher -orphan
end

# Post setup
if contains auth in $selected
    gum style "Post auth"
    echo "Run the following to use the cli in your shell or execute this script with `source setup.fish`"
    echo "set -x BAO_ADDR http://localhost:8200"
end

if test (count $selected) -eq 0
    echo "Nothing selected"
end
