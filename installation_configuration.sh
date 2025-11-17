#!/bin/bash
set -e
AMI_ID="ami-087d1c9a513324697"
read -p "How many MongoDB servers to launch? " COUNT
read -p "Enter EC2 Instance Type (t3.micro etc): " INSTANCE_TYPE
read -p "Enter AWS Key Pair Name: " KEY_NAME
read -p "Enter PEM Key File Path: " KEY_PATH
read -p "Enter Security Group ID: " SECURITY_GROUP
read -p "Enter Subnet ID: " SUBNET_ID
chmod 400 "$KEY_PATH"
IP_FILE="/tmp/mongo_ips.txt"
> "$IP_FILE"
echo "Launching $COUNT EC2 instances..."
for ((i=1;i<=COUNT;i++)); do
  read -p "Enter server-$i Name: " INSTANCE_NAME
  echo "Launching server-$i..."
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP \
    --subnet-id $SUBNET_ID \
    --query 'Instances[0].InstanceId' \
    --output text)
  aws ec2 create-tags --resources "$INSTANCE_ID" --tags Key=Name,Value="$INSTANCE_NAME"
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
 --query 'Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddress' \
 --output text)
  echo $PRIVATE_IP >> $IP_FILE
  echo "Instance Name: $INSTANCE_NAME"
  echo "Private IP: $PRIVATE_IP"
done
echo "Hold on, preparing all the nodes... wait time: 90s"
sleep 90
echo "=== Server IP List ==="
cat $IP_FILE
echo "Starting MongoDB installation on all the nodes..."
sleep 5
while read IP; do
  [ -z "$IP" ] && continue
  scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$IP_FILE" ubuntu@"$IP":/tmp/mongo_ips.txt
  scp -o StrictHostKeyChecking=no -i "$KEY_PATH" "$KEY_PATH" ubuntu@"$IP":/home/ubuntu/DB-Team-KeyPair.pem
  ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" ubuntu@"$IP" << EOF
sudo apt-get update -y
sudo apt-get install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.2.list
sudo apt-get update -y
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod
sudo sed -i 's/^  port:.*/  port: 27717/' /etc/mongod.conf
sudo sed -i 's/^  bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf
sudo sed -i 's/#replication:/replication:/' /etc/mongod.conf
grep -q replSetName /etc/mongod.conf || sudo sed -i '/^replication:/a\  replSetName: "repl"' /etc/mongod.conf
grep -q "^#security:" /etc/mongod.conf || sudo sed -i '/^# processManagement:/i #security:' /etc/mongod.conf
grep -q "#authorization:" /etc/mongod.conf || sudo sed -i '/^#security:/a\  #authorization: enabled' /etc/mongod.conf
grep -q "#keyFile:" /etc/mongod.conf || sudo sed -i '/^#security:/a\  #keyFile: /var/lib/mongodb/keyfile.key' /etc/mongod.conf
sudo systemctl restart mongod
echo "Successfully changed the mongodb configurations."
sudo systemctl status mongod
z=1
while read ip; do
  entry="$ip mongo$z"
  grep -q "$entry" /etc/hosts || echo "$entry" | sudo tee -a /etc/hosts >/dev/null
  z=$((z+1))
done < /tmp/mongo_ips.txt
EOF
done < $IP_FILE
