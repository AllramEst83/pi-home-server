# Pi home server (Docker)

Everything runs in Docker on the Pi (192.168.0.43) in `~/stacks`.
Traefik is the only container with an open port (80). It gives every app
two names, `<app>.local` and `<app>.192-168-0-43.sslip.io`, and lets only
the home network (192.168.0.0/24) in.

| App | Short name | Always works |
|---|---|---|
| Homepage (start page) | http://home.local | http://home.192-168-0-43.sslip.io |
| Adminer (databases) | http://adminer.local | http://adminer.192-168-0-43.sslip.io |
| File Browser (home folder) | http://files.local | http://files.192-168-0-43.sslip.io |
| RetroArch (games) | http://retroarch.local | http://retroarch.192-168-0-43.sslip.io |
| MUD (Evennia) | http://mud.local | http://mud.192-168-0-43.sslip.io |
| Glances | http://glances.local | http://glances.192-168-0-43.sslip.io |
| Traefik dashboard | http://traefik.local | http://traefik.192-168-0-43.sslip.io |

`.local` names are announced by the Pi itself (mDNS, via Avahi). They work on
Windows, iPhone and Mac; on Android it depends on the phone. Type
`glances.local/` the first time so the browser doesn't search for it.

## Layout

```
~/stacks/
  .env            DOMAIN and LAN_RANGE, used by every app
  compose.yml     the list of apps (include:)
  traefik/        the front door
  glances/        system monitor
  home/           Homepage, the start page (settings in home/config/)
  _template/      copy this for a new app
  mdns/           announces <app>.local names on the home network
  <app>/data/     each app's data (back up the folder)
```

## First-time setup (fresh Pi, done once)

Needs Docker with the compose plugin, and Avahi (Raspberry Pi OS has it).

1. From the PC, copy this folder to the Pi:
   ```bash
   scp -r C:/Users/kaywi/dev/pi-home-server/. allramest@192.168.0.43:stacks/
   ```
2. On the Pi, create the shared network every app joins:
   ```bash
   docker network create proxy
   ```
3. Install the `.local` name service:
   ```bash
   cd ~/stacks
   sudo install -m 755 mdns/mdns-alias /usr/local/bin/mdns-alias
   sudo install -m 644 mdns/mdns-alias@.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```
4. Start all apps:
   ```bash
   cd ~/stacks && docker compose up -d
   ```
5. Announce a `.local` name for each app:
   ```bash
   sudo systemctl enable --now mdns-alias@traefik mdns-alias@glances mdns-alias@home
   ```
6. Check from the PC: open http://home.local. It links to every app.

## Add a new app (repeat for every app)

On the Pi (`ssh allramest@192.168.0.43`):

1. Copy the template:
   ```bash
   cd ~/stacks
   cp -r _template myapp
   nano myapp/compose.yml
   ```
2. In `myapp/compose.yml` replace:
   - `APPNAME` with the app's name (all 4 places, lower case, no spaces). It
     becomes the address: `myapp.192-168-0-43.sslip.io`.
   - `IMAGE` with the Docker image, e.g. `louislam/uptime-kuma:1`.
   - `PORT` with the port the app listens on **inside** the container
     (the image's docs say; e.g. Uptime Kuma 3001).
   - the `volumes:` line with where the image keeps its data
     (e.g. `./data:/app/data` for Uptime Kuma).
   - Do **not** add a `ports:` section. Traefik is the way in.
   - The `homepage.*` labels put the app on http://home.local: set its
     group, a short description, and an icon name from
     https://dashboardicons.com (e.g. `uptime-kuma.png`).
3. Add the app to `~/stacks/compose.yml`:
   ```yaml
   include:
     - traefik/compose.yml
     - glances/compose.yml
     - myapp/compose.yml
   ```
4. Start it:
   ```bash
   cd ~/stacks && docker compose up -d
   ```
5. Announce the short name `myapp.local`:
   ```bash
   sudo systemctl enable --now mdns-alias@myapp
   ```
6. Open `http://myapp.local` (or `http://myapp.192-168-0-43.sslip.io`).
   It's on http://home.local too (reload the page).

Nothing else is needed: no DNS entry, no router change, no Traefik restart.
Traefik picks the new container up by its labels.

## Database (PostgreSQL + Adminer)

- Server: `postgres.local`, port `5432`, user `postgres`. Other containers
  use host `postgres`. Open to the home network only.
- Password: on the Pi, `cat ~/stacks/postgres/secrets.env`. It was made once
  with `echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" > secrets.env`
  (file mode 600) and is never committed (`.gitignore`).
- Adminer, the web manager: http://adminer.local. Pick System
  **PostgreSQL**, Server `postgres`, user `postgres`, then the password.
- From the PC: DBeaver or VS Code (PostgreSQL extension), using the same
  details with host `postgres.local`.
- A database for a new app: in Adminer, "Create database", or
  `docker exec -it postgres createdb -U postgres myapp`.
- Backup: `docker exec postgres pg_dumpall -U postgres > backup.sql`.
- PostgreSQL stays on version 17. Moving to 18 needs a dump and restore.

## File Browser

- http://files.local shows `/home/allramest` (read and write), which
  includes `~/stacks` and every app's data. It runs as your user.
- First login: user `admin`. The password is printed once in the log:
  `docker logs files 2>&1 | grep -i password`. Change it straight away
  (Settings > Profile).
- Careful with `~/stacks/*/data`: deleting there deletes app data.

## RetroArch (games)

- http://retroarch.local runs the RetroArch emulator in the browser. The
  game runs on the device you play on, not on the Pi.
- Nothing is stored on the Pi. Games you load and your saves stay in that
  browser, so clearing the browser's data deletes them.
- Load a game: click **Add content** in the top bar and pick a ROM file on
  your device. Then use Load Core and Load Content in the menu. Only use
  games you are allowed to use.

## MUD (Evennia)

Our own text-based multiplayer RPG.

- Play in the browser at http://mud.local, or with a MUD client: host
  `mud.local`, port `4000`.
- Besides port 80, it opens ports 4000 (telnet) and 4002 (the browser
  client's live connection). Home network only.
- Before the first start, make the admin account (once, on the Pi):
  ```bash
  cd ~/stacks/mud
  (umask 077; printf 'EVENNIA_SUPERUSER_USERNAME=admin
EVENNIA_SUPERUSER_PASSWORD=%s
' "$(openssl rand -hex 12)" > secrets.env)
  cat secrets.env
  ```
- Start: `cd ~/stacks && docker compose up -d --build`
- The game is in `~/stacks/mud/data/mymud` (code in `world/`, `typeclasses/`
  and `commands/`). The files belong to root, so edit them with `sudo`.
  After a change: `docker compose restart mud`.
- Backup: the `mud/data` folder.

## Everyday commands (in ~/stacks)

| What | Command |
|---|---|
| Status of all apps | `docker compose ps` |
| Logs of one app | `docker compose logs -f myapp` |
| Restart one app | `docker compose restart myapp` |
| Update all images | `docker compose pull && docker compose up -d` |
| Remove old images | `docker image prune -f` |
| Stop and remove one app | delete its line in `compose.yml`, then `docker compose up -d --remove-orphans` |

## When things don't open

- `404 page not found`: Traefik is running but has no app with that name.
  Check the `Host(...)` label and that `traefik.enable=true` is there.
- `Bad Gateway`: wrong `PORT` in the labels, or the app has crashed
  (`docker compose logs myapp`).
- `Forbidden`: you're not on the home network.
- The Traefik dashboard (http://traefik.192-168-0-43.sslip.io) lists every
  router and whether it's healthy.

## Notes

- Homepage: the top bar (CPU, memory, temperature, disk) is in
  `home/config/widgets.yaml`; things that aren't containers on the Pi (the
  router, other devices) go in `home/config/services.yaml`. Changes show
  after a page reload.

- Home-only: never forward ports on the router. For access from outside
  later, use Tailscale.
- Switching to fully local names: once you have your own DNS (e.g.
  AdGuard Home with a rewrite `*.pi.home.arpa -> 192.168.0.43`), set
  `DOMAIN=pi.home.arpa` in `.env` and run `docker compose up -d`.
- A `.local` name follows the Pi's current address (e.g. if it falls back
  to Wi-Fi). See which are announced: `systemctl list-units 'mdns-alias@*'`.
  Remove one: `sudo systemctl disable --now mdns-alias@myapp`.
- Glances runs in Docker's network, so its network panel shows the
  container's traffic, not the whole Pi's. CPU, memory, temperatures, disk,
  processes and containers are the Pi's.
