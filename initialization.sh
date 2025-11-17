#!/bin/bash
set -e
KEY_PATH="/home/ubuntu/DB-Team-KeyPair.pem"
IP_FILE="/tmp/mongo_ips.txt"
KEYFILE_LOCAL="/tmp/keyfile.key"
LOCAL_IP=$(hostname -I | awk '{print $1}')
sudo sh -c "openssl rand -base64 756 > /var/lib/mongodb/keyfile.key"
sudo chmod 400 /var/lib/mongodb/keyfile.key
sudo chown mongodb:mongodb /var/lib/mongodb/keyfile.key
cp /var/lib/mongodb/keyfile.key "$KEYFILE_LOCAL"
sudo sed -i 's/^[[:space:]]*#\s*security:/security:/' /etc/mongod.conf
sudo sed -i 's|^[[:space:]]*#\s*keyFile:.*|  keyFile: /var/lib/mongodb/keyfile.key|' /etc/mongod.conf
sudo sed -i 's/^[[:space:]]*#\s*authorization:.*/  authorization: enabled/' /etc/mongod.conf
sudo systemctl restart mongod
while read IP; do
    [ -z "$IP" ] && continue
    [ "$IP" = "$LOCAL_IP" ] && continue
    scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$KEYFILE_LOCAL" ubuntu@"$IP":/tmp/
    ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$IP" << 'EOF'
sudo mv /tmp/keyfile.key /var/lib/mongodb/
sudo chmod 400 /var/lib/mongodb/keyfile.key
sudo chown mongodb:mongodb /var/lib/mongodb/keyfile.key
sudo sed -i 's/^[[:space:]]*#\s*security:/security:/' /etc/mongod.conf
sudo sed -i 's|^[[:space:]]*#\s*keyFile:.*|  keyFile: /var/lib/mongodb/keyfile.key|' /etc/mongod.conf
sudo sed -i 's/^[[:space:]]*#\s*authorization:.*/  authorization: enabled/' /etc/mongod.conf
sudo systemctl restart mongod
EOF
done < "$IP_FILE"
MEMBERS=""
i=0
while read IP; do
    [ -z "$IP" ] && continue
    MEMBERS="$MEMBERS{ _id: $i, host: \"$IP:27717\" },"
    i=$((i+1))
done < "$IP_FILE"
MEMBERS="[${MEMBERS%,}]"
mongosh --quiet --norc --port 27717 --eval "
rs.initiate({
  _id: 'repl',
  members: $MEMBERS
});
"
echo "###########################################"
echo "Replica set initiated successfully."
echo "Members:"
while read IP; do
    [ -z "$IP" ] && continue
    echo "$IP"
done < "$IP_FILE"
echo "###########################################"
