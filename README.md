# DietPi Emergency Restore

Progetto **pubblico**, privo di credenziali, per salvare su Google Drive (Restic)
solo script personalizzati, Cron e servizi/timer systemd, con inventario.
Non è un'immagine completa di DietPi o dei container.

## Repository dei backup cifrati

`rclone:gdrive:backup_raspi/dietpi-script-cron-systemd`

Il backup incrementale gira **ogni notte alle 03:00** con il Cron di root:

```cron
0 3 * * * /bin/bash /mnt/usbtdk/emergency_restore/backup.sh >> /var/log/emergency-restore-backup.log 2>&1
```

Per lanciarlo manualmente: `sudo bash /mnt/usbtdk/emergency_restore/backup.sh`.
I backup NON cancellano snapshot precedenti e non eseguono `prune`.

## Cosa viene salvato

- `/mnt/usbtdk/scripts`, `/usr/local/bin`, `/usr/local/sbin`, `/opt/scripts`.
- Crontab di tutti gli utenti, `/etc/cron.*`, `/etc/crontab`.
- File personalizzati in `/etc/systemd/system`, `/etc/systemd/user` e cartelle utente.
- Inventario in `/var/lib/emergency-restore/inventory/` (servizi e timer abilitati).
- Script `.sh` e `.py` in `/root`, `/home`, e fino a 5 livelli in `/mnt/usbtdk/docker`.
- Gli script di questo progetto, **senza** la directory Git `.git`.

Non sono garantiti file con nomi o percorsi insoliti, dipendenze installate
con apt, database Docker o credenziali non incluse nei percorsi sopra elencati.
Alcuni file del backup cifrato possono contenere segreti: **non renderli pubblici**.

## Credenziali: SOLO KeePass

Il kit privato KeePass è creato **una volta** dall'installatore in `/run`.
Non viene mai incluso nel progetto GitHub, né rigenerato dal Cron.
Conserva in KeePass l'allegato `keepass-emergency-restore-*.tar.gz` che contiene:

- `rclone.conf` (autorizzazione Google Drive)
- `dietpi-usb-restic.pass` (password di decifratura Restic)
- `LEGGIMI-PRIVATO.txt` (posizioni e istruzioni)

Se cambi le credenziali, aggiorna manualmente il kit KeePass.
L'archivio TAR non è cifrato da solo: proteggilo finché non è in KeePass.

## Recupero su un nuovo DietPi

1. Installa i pacchetti: `sudo apt-get update && sudo apt-get install -y restic rclone git`.
2. Estrai l'allegato privato da KeePass e posiziona:
   - `rclone.conf` in `/root/.config/rclone/rclone.conf`
   - `dietpi-usb-restic.pass` in `/root/.config/restic/dietpi-usb-restic.pass`
3. Proteggi file/directory: `chmod 700 /root/.config/{rclone,restic}` e `chmod 600` sui due file.
4. Clona questo progetto GitHub e consulta i backup:

```bash
bash esplora.sh snapshots
bash esplora.sh lista latest
bash esplora.sh leggi latest /mnt/usbtdk/scripts/docker-update.sh
bash esplora.sh recupera latest /mnt/usbtdk/scripts/docker-update.sh
```

`recupera` estrae **solo** in `/root/recupero-emergency-restore`,
non sovrascrive i file di sistema. Esamina i file prima di ripristinarli.
Per Cron, valuta prima il testo di ogni utente: `crontab -u UTENTE file.txt`
**sostituisce** il crontab di quell'utente.
Per systemd, copia manualmente le unit selezionate, controlla dipendenze,
poi `systemctl daemon-reload` e abilita solo i timer/servizi necessari.

## Verifiche

`bash esplora.sh snapshots` mostra gli snapshot e `bash esplora.sh lista latest`
ne elenca il contenuto. Il log del backup automatico è
`/var/log/emergency-restore-backup.log`.
