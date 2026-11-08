#!/usr/bin/env bash
set -Eeuo pipefail
export RESTIC_REPOSITORY='rclone:gdrive:backup_raspi/dietpi-script-cron-systemd'
export RESTIC_PASSWORD_FILE='/root/.config/restic/dietpi-usb-restic.pass'
export RCLONE_CONFIG='/root/.config/rclone/rclone.conf'
[ "$(id -u)" -eq 0 ] || { echo 'Esegui come root'; exit 1; }
case "${1:-}" in
  snapshots) restic snapshots ;;
  lista) restic ls "${2:-latest}" ;;
  leggi)
    [ "$#" -eq 3 ] || { echo 'Uso: leggi SNAPSHOT /percorso/file'; exit 1; }
    restic dump "$2" "$3" ;;
  recupera)
    [ "$#" -eq 3 ] || { echo 'Uso: recupera SNAPSHOT /percorso/file'; exit 1; }
    dest=/root/recupero-emergency-restore
    mkdir -p "$dest"
    restic restore "$2" --target "$dest" --include "$3"
    echo "Recuperato in $dest (NON sovrascritto sul sistema attivo)" ;;
  *) echo 'Uso: esplora.sh snapshots | lista [SNAP] | leggi SNAP /file | recupera SNAP /file'; exit 1 ;;
esac
