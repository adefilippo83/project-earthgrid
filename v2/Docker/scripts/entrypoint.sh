#!/bin/bash
set -e

# Verifica variabili d'ambiente essenziali
if [ -z "$NODE_NAME" ]; then
    echo "ERROR: NODE_NAME non definito"
    exit 1
fi

if [ -z "$INTERNAL_VPN_IP" ]; then
    echo "ERROR: INTERNAL_VPN_IP non definito"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "ERROR: GITHUB_REPO non definito. Formato richiesto: utente/repository"
    exit 1
fi

if [ -z "$GPG_KEY_ID" ]; then
    echo "ERROR: GPG_KEY_ID non definito. È necessario fornire l'ID della chiave GPG esistente"
    exit 1
fi

# Verifica la presenza della chiave GPG
echo "Verifica chiave GPG con ID: $GPG_KEY_ID"
if ! gpg --list-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
    # Se la chiave è stata fornita come variabile d'ambiente
    if [ ! -z "$GPG_PRIVATE_KEY" ]; then
        echo "Importazione chiave GPG da variabile d'ambiente..."
        echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    # Altrimenti cerchiamo il file di chiave privata montato
    elif [ -f "/run/secrets/gpg_private_key" ]; then
        echo "Importazione chiave GPG da file montato (Docker secret)..."
        gpg --batch --import /run/secrets/gpg_private_key
    # Se la directory .gnupg è stata montata come volume, verifichiamo di nuovo
    elif [ -d "/root/.gnupg" ] && [ "$(ls -A /root/.gnupg)" ]; then
        echo "Utilizzo keyring GPG esistente montato come volume..."
    else
        echo "ERROR: Chiave GPG $GPG_KEY_ID non trovata e nessuna chiave privata fornita."
        echo "È necessario fornire una chiave GPG esistente tramite:"
        echo "1. Docker secret (gpg_private_key)"
        echo "2. Variabile d'ambiente GPG_PRIVATE_KEY"
        echo "3. Volume montato con keyring GPG esistente"
        exit 1
    fi
    
    # Verifica che la chiave sia ora disponibile
    if ! gpg --list-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
        echo "ERROR: Impossibile importare la chiave GPG $GPG_KEY_ID"
        exit 1
    fi
fi

# Controllo della chiave privata
if ! gpg --list-secret-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
    echo "ERROR: La chiave privata per $GPG_KEY_ID non è disponibile"
    exit 1
fi

echo "Chiave GPG $GPG_KEY_ID verificata con successo"

# Setup iniziale
/app/scripts/setup-tinc.sh

# Configura sincronizzazione periodica
if [ "$ENABLE_AUTO_DISCOVERY" = "true" ] || [ "$ENABLE_AUTO_DISCOVERY" = "1" ]; then
    echo "Configurazione sincronizzazione automatica..."
    SYNC_INTERVAL=${SYNC_INTERVAL:-3600}
    SYNC_CRON="*/$(($SYNC_INTERVAL / 60)) * * * * /app/scripts/sync-manifest.sh >> /var/log/sync-manifest.log 2>&1"
    echo "$SYNC_CRON" > /etc/cron.d/sync-manifest
    chmod 0644 /etc/cron.d/sync-manifest
    cron
fi

# Prima sincronizzazione
/app/scripts/sync-manifest.sh

# Avvio Tinc in modalità foreground
echo "Avvio di Tinc VPN..."
exec tincd -n earthgrid -D -d3