#!/bin/bash
set -e

# Directory per il repository clonato
MANIFEST_DIR="/var/lib/earthgrid/manifest"
mkdir -p $MANIFEST_DIR

# Creazione della configurazione base di Tinc
mkdir -p /etc/tinc/earthgrid/hosts

# Configurazione tinc.conf
cat > /etc/tinc/earthgrid/tinc.conf << EOF
Name = ${NODE_NAME}
Interface = tun0
Mode = switch
AddressFamily = ipv4
EOF

# Configurazione host locale
cat > /etc/tinc/earthgrid/hosts/${NODE_NAME} << EOF
Subnet = ${INTERNAL_VPN_IP}/32
EOF

if [ ! -z "$PUBLIC_IP" ]; then
    if [ "$PUBLIC_IP" = "auto" ]; then
        PUBLIC_IP=$(curl -s https://api.ipify.org)
    fi
    echo "Address = ${PUBLIC_IP}" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
    echo "Port = 655" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
fi

# Generazione o importazione chiavi Tinc
if [ ! -f /etc/tinc/earthgrid/rsa_key.priv ]; then
    if [ ! -z "$TINC_PRIVATE_KEY" ]; then
        echo "Utilizzo chiave Tinc fornita tramite variabile d'ambiente..."
        echo "$TINC_PRIVATE_KEY" > /etc/tinc/earthgrid/rsa_key.priv
        chmod 600 /etc/tinc/earthgrid/rsa_key.priv
    elif [ -f "/run/secrets/tinc_private_key" ]; then
        echo "Utilizzo chiave Tinc fornita tramite Docker secret..."
        cp /run/secrets/tinc_private_key /etc/tinc/earthgrid/rsa_key.priv
        chmod 600 /etc/tinc/earthgrid/rsa_key.priv
    else
        echo "Generazione nuova chiave RSA per Tinc..."
        tincd -n earthgrid -K4096
    fi
fi

# Export della chiave pubblica GPG
echo "Esportazione chiave pubblica GPG..."
gpg --armor --export "$GPG_KEY_ID" > /etc/tinc/earthgrid/hosts/${NODE_NAME}.gpg

# Firma del file host con GPG
echo "Firma del file host con chiave GPG $GPG_KEY_ID..."
gpg --detach-sign -a --default-key "$GPG_KEY_ID" /etc/tinc/earthgrid/hosts/${NODE_NAME}

# Script tinc-up
cat > /etc/tinc/earthgrid/tinc-up << EOF
#!/bin/sh
ip link set \$INTERFACE up
ip addr add ${INTERNAL_VPN_IP}/16 dev \$INTERFACE
EOF
chmod +x /etc/tinc/earthgrid/tinc-up

# Script tinc-down
cat > /etc/tinc/earthgrid/tinc-down << EOF
#!/bin/sh
ip addr del ${INTERNAL_VPN_IP}/16 dev \$INTERFACE
ip link set \$INTERFACE down
EOF
chmod +x /etc/tinc/earthgrid/tinc-down

echo "Configurazione base Tinc completata."