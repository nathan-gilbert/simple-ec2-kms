#!/bin/bash
apt update -y
# Ubuntu also requires distro level python packages to be installed
apt install -y python3 unzip python3-pip curl python3-flask python3-psycopg2 python3-boto3

# Must download and install the AWS CLI v2 on Ubuntu 22.04
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# The encrypted database password
encrypted_password_base64="${encrypted_password}"

# Decrypt the database password using KMS
db_password=$(echo $encrypted_password_base64 | base64 --decode | aws kms decrypt --ciphertext-blob fileb:///dev/stdin --output text --query Plaintext | base64 --decode)

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

cat <<EOF > /home/ubuntu/app.py
from flask import Flask
import psycopg2

app = Flask(__name__)

@app.route("/")
def hello():
    conn = psycopg2.connect(
        dbname="${db_name}",
        user="${db_user}",
        password="$db_password",
        host="${db_endpoint}",
        port="5432"
    )
    cur = conn.cursor()
    cur.execute("SELECT 'Hello, World!'")
    result = cur.fetchone()
    cur.close()
    conn.close()
    return result[0]

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
EOF

python3 /home/ubuntu/app.py &
