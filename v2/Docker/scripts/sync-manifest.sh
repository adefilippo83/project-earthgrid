#!/bin/bash
set -e

MANIFEST_DIR="/var/lib/earthgrid/manifest"
BRANCH="${GITHUB_BRANCH:-main}"
MANIFEST_FILE="${MANIFEST_FILENAME:-manifest.yaml}"

echo "$(date): Inizio sincronizzazione manifest da GitHub..."

# Clona o aggiorna il repository
if [ ! -d "$MANIFEST_DIR/.git" ]; then
    echo "Clonazione iniziale del repository..."
    git clone --depth 1 -b $BRANCH https://github.com/$GITHUB_REPO.git $MANIFEST_DIR
else
    echo "Aggiornamento repository esistente..."
    cd $MANIFEST_DIR
    git fetch
    git reset --hard origin/$BRANCH
fi

# ... [codice esistente per l'elaborazione dei nodi] ...

# Verifica la chiave GPG per ogni nodo
for NODE in $(cat $MANIFEST_DIR/$MANIFEST_FILE | grep -A5 "name:" | grep -v "^\-\-" | grep -oP "name: \K[^\s]+" | sort | uniq); do
    if [ "$NODE" = "$NODE_NAME" ]; then
        continue  # Salta il nodo corrente
    fi
    
    # Estrai il GPG_KEY_ID dal manifest
    NODE_GPG_KEY=$(grep -A5 "name: $NODE" $MANIFEST_DIR/$MANIFEST_FILE | grep "gpg_key_id" | awk '{print $2}')
    
    if [ -z "$NODE_GPG_KEY" ]; then
        echo "Nodo $NODE saltato: chiave GPG non definita"
        continue
    fi
    
    # Scarica la chiave GPG se non presente localmente
    if ! gpg --list-keys "$NODE_GPG_KEY" > /dev/null 2>&1; then
        echo "Scaricamento chiave GPG $NODE_GPG_KEY per $NODE..."
        gpg --keyserver keys.openpgp.org --recv-keys "$NODE_GPG_KEY"
        
        if [ $? -ne 0 ]; then
            echo "AVVISO: Impossibile scaricare la chiave GPG $NODE_GPG_KEY per $NODE"
            continue
        fi
    fi
    
    # ... [resto del codice per configurare i nodi] ...
done

echo "$(date): Sincronizzazione manifest completata con successo."