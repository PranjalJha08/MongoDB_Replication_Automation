# MongoDB Automated 3-Node Replica Set Deployment (MongoDB 8.x)

This repository contains two bash scripts that fully automate the deployment of MongoDB 8.x replica set nodes on AWS EC2 instances. The setup includes EC2 provisioning, MongoDB installation, configuration updates, keyFile-based internal authentication, and automatic replica set initiation.

---

## **Overview**

This solution deploys an end-to-end MongoDB replica set:

* Launch EC2 servers
* Install and configure MongoDB 8.x
* Apply custom port **27717**
* Set up `/etc/hosts` mapping
* Generate and distribute keyfile
* Enable security + authorization
* Initiate the replica set

All steps are fully automated using two scripts:

* **Script 1 → EC2 Launch + MongoDB Install + Basic Config**
* **Script 2 → Keyfile Auth Setup + Replica Set Initiation**

---

## **Files Included**

### **1. `script1.sh`**

Automates EC2 instance creation and initial MongoDB setup.

### **2. `script2.sh`**

Configures keyfile-based authentication and initiates replica set.

---

## **Prerequisites**

Before running the scripts:

1. AWS CLI must be configured:

```
aws configure
```

2. Ensure you have the PEM key file locally.
3. Ensure the target Security Group allows:

   * **TCP 22** (SSH)
   * **TCP 27717** (MongoDB)
4. Scripts must be executable:

```
chmod +x script1.sh script2.sh
```

---

## **How Script 1 Works**

Script 1 performs the following:

### ✔ Launches EC2 Instances

Prompts for:

* Number of MongoDB nodes
* Instance type
* Key pair name
* Security group
* Subnet ID

Each server is tagged with a custom name.

### ✔ Captures and stores Private IPs

All private IPs are saved in:

```
/tmp/mongo_ips.txt
```

### ✔ Installs MongoDB 8.x on all servers

Steps include:

* Adding MongoDB APT repo
* Installing `mongodb-org`
* Starting + enabling service

### ✔ Updates MongoDB configuration

* Custom port **27717**
* Bind to **0.0.0.0**
* Enable replica set section
* Prepare commented security fields

### ✔ Updates /etc/hosts mapping

Adds entries like:

```
10.0.1.10 mongo1
10.0.1.11 mongo2
10.0.1.12 mongo3
```

---

## **How Script 2 Works**

Script 2 handles authentication and replica set initialization.

### ✔ Generates keyfile on first node

Creates keyfile at:

```
/var/lib/mongodb/keyfile.key
```

Permissions applied:

```
chmod 400
chown mongodb:mongodb
```

### ✔ Distributes keyfile to all other nodes

Copies securely using scp.

### ✔ Enables Security + Authorization

Updates:

```
security:
  keyFile: /var/lib/mongodb/keyfile.key
  authorization: enabled
```

### ✔ Restarts MongoDB on all nodes

Ensures secure communication.

### ✔ Initiates Replica Set Automatically

Builds members list based on IP file:

```
rs.initiate({ _id: 'repl', members: [...] })
```

### ✔ Prints Final Members List

```
Replica set initiated successfully.
Members:
10.0.1.10
10.0.1.11
10.0.1.12
```

---

## **Running the Scripts**

### **Step 1: Launch EC2 + Install MongoDB**

```
./script1.sh
```

Follow prompts.

### **Step 2: Configure Keyfile + Initiate Replica Set**

Run on **any one** MongoDB node:

```
./script2.sh
```

---

## **Directory Structure**

```
├── script1.sh
├── script2.sh
└── README.md
```

---

## **Notes & Best Practices**

* Script 2 must run only once.
* To add more nodes later, update IP file and rerun key distribution manually.
* Ensure EC2 instances have IAM roles or AWS CLI credentials when running script1.

---

## **Troubleshooting**

### MongoDB not starting?

Run:

```
sudo journalctl -u mongod -xe
```

### Replica set errors?

Check connectivity:

```
telnet <ip> 27717
```

### Keyfile permission denied?

Ensure:

```
chmod 400 keyfile.key
chown mongodb:mongodb keyfile.key
```

---

## **License**

MIT License.

---

## **Author**

Pranjal Jha – Database Administrator & Automation Engineer

---

## **Contributions**

Pull requests are welcome for improvements or additional features.
