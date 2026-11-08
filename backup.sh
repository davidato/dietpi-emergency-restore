#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[ "$(id -u)" -eq 0 ] || { echo 'Esegui come root'; exit 1; }
export RESTIC_REPOSITORY='rclone:gdrive:backup_raspi/dietpi-script-cron-systemd'
export RESTIC_PASSWORD_FILE='/root/.config/restic/dietpi-usb-restic.pass'
export RCLONE_CONFIG='/root/.config/rclone/rclone.conf'
export GOMAXPROCS=1
[ -s "$RESTIC_PASSWORD_FILE" ] && [ -s "$RCLONE_CONFIG" ] || {
  echo 'Credenziali Restic/Rclone mancanti'; exit 1;
}
exec 9>/run/lock/emergency-restore.lock
flock -n 9 || { echo 'Backup già in corso'; exit 1; }

INV=/var/lib/emergency-restore/inventory
mkdir -p "$INV/cron-utenti"
# Non conservare inventari obsoleti di utenti rimossi.
find "$INV/cron-utenti" -maxdepth 1 -type f -name '*.txt' -delete
while IFS=: read -r user _; do
  crontab -u "$user" -l > "$INV/cron-utenti/$user.txt" 2>/dev/null ||
    rm -f "$INV/cron-utenti/$user.txt"
done </etc/passwd
systemctl list-unit-files --all --no-pager > "$INV/systemd-unit-files.txt"
systemctl list-unit-files --state=enabled --no-pager > "$INV/systemd-enabled.txt"
systemctl list-timers --all --no-pager > "$INV/systemd-timers.txt"

STAGE=$(mktemp -d /run/emergency-list-XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
LIST="$STAGE/files.bin"
: > "$LIST"
for p in \
  /mnt/usbtdk/emergency_restore /mnt/usbtdk/scripts \
  /usr/local/bin /usr/local/sbin /opt/scripts \
  /etc/crontab /etc/anacrontab /etc/cron.d \
  /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly \
  /var/spool/cron/crontabs \
  /etc/systemd/system /etc/systemd/user /usr/local/lib/systemd/system \
  /root/.config/systemd/user /etc/rc.local \
  "$INV"; do
  if [ -e "$p" ] || [ -L "$p" ]; then printf '%s\0' "$p" >> "$LIST"; fi
done
for d in /root /home; do
  if [ -d "$d" ]; then
    find "$d" -maxdepth 4 -type f \
      \( -name '*.sh' -o -name '*.py' \) -print0 >> "$LIST"
  fi
done
if [ -d /home ]; then
  find /home -type d -path '*/.config/systemd/user' -prune -print0 >> "$LIST"
fi
if [ -d /mnt/usbtdk/docker ]; then
  find /mnt/usbtdk/docker -maxdepth 5 \
    \( -type d \( -name '.git' -o -name 'node_modules' -o -name '.venv' \) -prune \) -o \
    \( -type f \( -name '*.sh' -o -name '*.py' \) -print0 \) >> "$LIST"
fi
[ -s "$LIST" ] || { echo 'Elenco file vuoto'; exit 1; }

# Controllo la cartella madre: il repository dedicato può non esistere ancora.
if ! rclone lsf gdrive:backup_raspi --dirs-only > "$STAGE/remote-dirs"; then
  echo 'Google Drive non raggiungibile: annullo'; exit 1
fi
if grep -Fxq 'dietpi-script-cron-systemd/' "$STAGE/remote-dirs"; then
  rclone lsf gdrive:backup_raspi/dietpi-script-cron-systemd --files-only > "$STAGE/remote-files" || exit 1
  grep -Fxq config "$STAGE/remote-files" || {
    echo 'Cartella dedicata già presente ma senza config Restic: non la sovrascrivo'; exit 1;
  }
  restic cat config >/dev/null
else
  restic init
fi

echo '=== BACKUP INCREMENTALE RESTIC ==='
if command -v ionice >/dev/null 2>&1; then
  ionice -c3 nice -n 15 restic backup --files-from-raw "$LIST" \
    --exclude '/mnt/usbtdk/emergency_restore/.git' \
    --tag script-cron-systemd --host DietPi3 2>&1 | tee "$STAGE/risultato.log"
else
  nice -n 15 restic backup --files-from-raw "$LIST" \
    --exclude '/mnt/usbtdk/emergency_restore/.git' \
    --tag script-cron-systemd --host DietPi3 2>&1 | tee "$STAGE/risultato.log"
fi
SNAP=$(sed -nE 's/^snapshot ([0-9a-f]+) saved$/\1/p' "$STAGE/risultato.log" | tail -1)
[ -n "$SNAP" ] || { echo 'Nessuna conferma snapshot: verifica fallita'; exit 1; }
restic ls "$SNAP" "$INV" > "$STAGE/contenuto.log"
grep -Fq 'systemd-enabled.txt' "$STAGE/contenuto.log" || {
  echo 'Inventario systemd mancante nello snapshot'; exit 1;
}
echo "VERIFICATO: snapshot $SNAP, inventario systemd presente"
