#!/bin/bash
apt update -y
# Ubuntu also requires distro level python packages to be installed
apt install -y python3 unzip python3-pip curl python3-flask python3-psycopg2 python3-boto3 jq

# Must download and install the AWS CLI v2 on Ubuntu 22.04
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Vault server endpoint and token
vault_url="http://172.234.224.217:8200/v1/flaskapp/db"
vault_token="${vault_token}"

# Retrieve the database password from Vault
db_password=$(curl --silent --header "X-Vault-Token: $vault_token" --request GET $vault_url | jq -r '.data.password')

# Create a Python script to create the database if it doesn't exist
cat <<EOF > /home/ubuntu/create_db.py
import psycopg2
import sys

def create_database():
    try:
        # Connect to PostgreSQL server
        conn = psycopg2.connect(
            dbname="postgres",
            user="${db_user}",
            password="$db_password",
            host="${db_endpoint}",
            port="5432"
        )
        conn.autocommit = True
        cur = conn.cursor()

        # Create the database if it doesn't exist
        cur.execute("SELECT 1 FROM pg_database WHERE datname = 'mydatabase'")
        exists = cur.fetchone()
        if not exists:
            cur.execute("CREATE DATABASE mydatabase")
            print("Database 'mydatabase' created successfully.")
        else:
            print("Database 'mydatabase' already exists.")

        cur.close()
        conn.close()
    except Exception as e:
        print("Error creating database:", e)
        sys.exit(1)

if __name__ == "__main__":
    create_database()
EOF

# Run the script to create the database
python3 /home/ubuntu/create_db.py
