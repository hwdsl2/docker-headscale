#!/bin/bash
#
# https://github.com/hwdsl2/docker-headscale
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

HS_CONFIG="/etc/headscale/config.yaml"
HS_SOCK="/var/run/headscale/headscale.sock"

exiterr() { echo "Error: $1" >&2; exit 1; }

show_usage() {
  if [ -n "$1" ]; then
    echo "Error: $1" >&2
  fi
  cat 1>&2 <<'EOF'

Headscale Docker - Server Management
https://github.com/hwdsl2/docker-headscale

Usage: docker exec <container> hs_manage [options]

Options:
  --listnodes               list all registered nodes
  --listusers               list all users
  --listnodes  --user <n>   list nodes for a specific user
  --adduser    <name>       add a new user
  --deleteuser <name>       delete a user (and all their nodes and keys)
  --deletenode <id>         delete a node by its numeric ID
  --registernode <key>      register a node by its node key
                            (requires --user <name>)
  --createkey  --user <n>   create a reusable pre-auth key for a user
  --listkeys                list all pre-auth keys
  -y, --yes                 assume "yes" for confirmation prompts
  -h, --help                show this help message and exit

Examples:
  docker exec headscale hs_manage --listusers
  docker exec headscale hs_manage --listnodes
  docker exec headscale hs_manage --adduser alice
  docker exec headscale hs_manage --registernode <key> --user alice
  docker exec headscale hs_manage --createkey --user alice
  docker exec headscale hs_manage --listkeys
  docker exec -it headscale hs_manage --deleteuser alice
  docker exec headscale hs_manage --deleteuser alice --yes
  docker exec -it headscale hs_manage --deletenode 3
  docker exec headscale hs_manage --deletenode 3 --yes

EOF
  exit 1
}

check_container() {
  if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
    && [ -z "$KUBERNETES_SERVICE_HOST" ] \
    && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
    exiterr "This script must be run inside a container (e.g. Docker, Podman)."
  fi
}

check_setup() {
  if [ ! -S "$HS_SOCK" ]; then
    exiterr "Headscale is not running (unix socket not found). Has the container started?"
  fi
  if [ ! -f "$HS_CONFIG" ]; then
    exiterr "Headscale config not found at $HS_CONFIG. Has the container started?"
  fi
}

hs_cmd() {
  headscale -c "$HS_CONFIG" "$@"
}

# Look up a user's numeric ID by username.
# Prints the numeric ID, or empty string if not found.
get_user_id() {
  local uname="$1"
  hs_cmd users list --name "$uname" -o json 2>/dev/null | \
    tr -d ' \n\t' | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2
}

parse_args() {
  list_nodes=0
  list_users=0
  add_user=0
  delete_user=0
  delete_node=0
  register_node=0
  create_key=0
  list_keys=0
  assume_yes=0
  target_user=""
  target_node_id=""
  target_node_key=""
  unsanitized_user=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --listnodes)
        list_nodes=1
        shift
        ;;
      --listusers)
        list_users=1
        shift
        ;;
      --adduser)
        add_user=1
        unsanitized_user="$2"
        shift; shift
        ;;
      --deleteuser)
        delete_user=1
        unsanitized_user="$2"
        shift; shift
        ;;
      --deletenode)
        delete_node=1
        target_node_id="$2"
        shift; shift
        ;;
      --registernode)
        register_node=1
        target_node_key="$2"
        shift; shift
        ;;
      --createkey)
        create_key=1
        shift
        ;;
      --listkeys)
        list_keys=1
        shift
        ;;
      --user)
        target_user="$2"
        shift; shift
        ;;
      -y|--yes)
        assume_yes=1
        shift
        ;;
      -h|--help)
        show_usage
        ;;
      *)
        show_usage "Unknown parameter: $1"
        ;;
    esac
  done
}

check_args() {
  local action_count
  action_count=$((list_nodes + list_users + add_user + delete_user + delete_node + register_node + create_key + list_keys))

  if [ "$action_count" -eq 0 ]; then
    show_usage
  fi
  if [ "$action_count" -gt 1 ]; then
    show_usage "Specify only one action at a time."
  fi

  # --adduser and --deleteuser require a name argument
  if [ "$add_user" = 1 ] || [ "$delete_user" = 1 ]; then
    local sanitized
    sanitized=$(printf '%s' "$unsanitized_user" | \
      sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g')
    if [ -z "$sanitized" ]; then
      exiterr "Invalid user name. Use one word only, no special characters except '-' and '_'."
    fi
    target_user="$sanitized"
  fi

  # --createkey requires --user
  if [ "$create_key" = 1 ]; then
    if [ -z "$target_user" ]; then
      exiterr "The --user <name> option is required with --createkey."
    fi
  fi

  # --deletenode requires a numeric ID
  if [ "$delete_node" = 1 ]; then
    if [ -z "$target_node_id" ]; then
      exiterr "--deletenode requires a node ID. Use '--listnodes' to find node IDs."
    fi
    if ! printf '%s' "$target_node_id" | grep -Eq '^[0-9]+$'; then
      exiterr "Node ID must be a positive integer. Use '--listnodes' to find node IDs."
    fi
  fi

  # --registernode requires a key and --user
  if [ "$register_node" = 1 ]; then
    if [ -z "$target_node_key" ]; then
      exiterr "--registernode requires a node key. Copy the key shown by 'tailscale up'."
    fi
    if [ -z "$target_user" ]; then
      exiterr "--registernode requires --user <name>. Use '--listusers' to find user names."
    fi
  fi
}

do_list_nodes() {
  echo
  if [ -n "$target_user" ]; then
    echo "Nodes for user '$target_user':"
    echo
    hs_cmd nodes list --user "$target_user" 2>&1
  else
    echo "All registered nodes:"
    echo
    hs_cmd nodes list 2>&1
  fi
  echo
}

do_list_users() {
  echo
  echo "Users:"
  echo
  hs_cmd users list 2>&1
  echo
}

do_add_user() {
  echo
  echo "Adding user '$target_user'..."
  if hs_cmd users create "$target_user" 2>&1; then
    echo
    echo "User '$target_user' created."
    echo "Create a pre-auth key for this user:"
    echo "  docker exec <container> hs_manage --createkey --user $target_user"
  else
    echo
    echo "Failed to create user '$target_user' (it may already exist)." >&2
    echo "Use '--listusers' to see existing users." >&2
    exit 1
  fi
  echo
}

do_delete_user() {
  if [ "$assume_yes" != 1 ]; then
    echo
    printf "Delete user '%s' and all their nodes and keys? This cannot be undone. [y/N]: " "$target_user"
    read -r confirm
    case "$confirm" in
      [yY][eE][sS]|[yY]) ;;
      *) echo; echo "Deletion aborted."; echo; exit 1 ;;
    esac
  fi
  echo
  echo "Deleting user '$target_user'..."
  if hs_cmd users delete --name "$target_user" --force 2>&1; then
    echo
    echo "User '$target_user' deleted."
  else
    echo
    echo "Failed to delete user '$target_user'." >&2
    echo "Use '--listusers' to verify the user name." >&2
    exit 1
  fi
  echo
}

do_delete_node() {
  if [ "$assume_yes" != 1 ]; then
    echo
    printf 'Delete node ID %s? This cannot be undone. [y/N]: ' "$target_node_id"
    read -r confirm
    case "$confirm" in
      [yY][eE][sS]|[yY]) ;;
      *) echo; echo "Deletion aborted."; echo; exit 1 ;;
    esac
  fi
  echo
  echo "Deleting node ID $target_node_id..."
  if hs_cmd nodes delete --identifier "$target_node_id" --force 2>&1; then
    echo
    echo "Node $target_node_id deleted."
  else
    echo
    echo "Failed to delete node $target_node_id." >&2
    echo "Use '--listnodes' to verify the node ID." >&2
    exit 1
  fi
  echo
}

do_register_node() {
  echo
  echo "Registering node for user '$target_user'..."
  if hs_cmd nodes register --user "$target_user" --key "$target_node_key" 2>&1; then
    echo
    echo "Node registered successfully."
  else
    echo
    echo "Failed to register node." >&2
    echo "Make sure the node key and user name are correct." >&2
    exit 1
  fi
  echo
}

do_create_key() {
  echo
  echo "Looking up user '$target_user'..."
  local user_id
  user_id=$(get_user_id "$target_user")
  if [ -z "$user_id" ]; then
    exiterr "User '$target_user' not found. Use '--listusers' to see existing users."
  fi

  echo "Creating reusable pre-auth key for user '$target_user' (ID: $user_id)..."
  echo
  if hs_cmd preauthkeys create \
      --user "$user_id" \
      --reusable \
      --expiration 90d 2>&1; then
    echo
    echo "Pre-auth key created (expires in 90 days)."
    echo "Connect a Tailscale client:"
    server_url=$(grep '^server_url:' "$HS_CONFIG" 2>/dev/null | awk '{print $2}')
    if [ -n "$server_url" ]; then
      echo "  tailscale up --login-server $server_url --authkey <key-above>"
    fi
  else
    echo
    echo "Failed to create pre-auth key for user '$target_user'." >&2
    exit 1
  fi
  echo
}

do_list_keys() {
  echo
  echo "All pre-auth keys:"
  echo
  hs_cmd preauthkeys list 2>&1
  echo
}

check_container
parse_args "$@"
check_args
check_setup

if [ "$list_nodes" = 1 ]; then
  do_list_nodes
  exit 0
fi

if [ "$list_users" = 1 ]; then
  do_list_users
  exit 0
fi

if [ "$add_user" = 1 ]; then
  do_add_user
  exit 0
fi

if [ "$delete_user" = 1 ]; then
  do_delete_user
  exit 0
fi

if [ "$delete_node" = 1 ]; then
  do_delete_node
  exit 0
fi

if [ "$register_node" = 1 ]; then
  do_register_node
  exit 0
fi

if [ "$create_key" = 1 ]; then
  do_create_key
  exit 0
fi

if [ "$list_keys" = 1 ]; then
  do_list_keys
  exit 0
fi