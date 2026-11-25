#!/bin/sh
# First start: creates the game in /data/mymud and the admin account.
# Every start: updates the database and runs the server.
set -e
GAME=/data/mymud

if [ ! -f "$GAME/server/conf/settings.py" ]; then
  if [ -z "$EVENNIA_SUPERUSER_USERNAME" ] || [ -z "$EVENNIA_SUPERUSER_PASSWORD" ]; then
    echo "No admin account set. Create mud/secrets.env (see README), then: docker compose up -d"
    exit 1
  fi
  cd /data
  evennia --init mymud
  cat >> "$GAME/server/conf/settings.py" <<'PY'

# Added by the container: allow logging in through Traefik under both names.
import os
CSRF_TRUSTED_ORIGINS = ["http://mud.local", "http://mud." + os.environ.get("DOMAIN", "localhost")]
PY
fi

cd "$GAME"
mkdir -p server/logs
# Left over if the container was killed; they stop the server from starting.
rm -f server/*.pid
evennia migrate

trap 'evennia stop; exit 0' TERM INT
evennia start -l &
wait $!
