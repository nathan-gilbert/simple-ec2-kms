#!/bin/bash
yum update -y
yum install -y python3
pip3 install flask psycopg2-binary boto3

# The encrypted database password
encrypted_password_base64="${encrypted_password}"

# Decrypt the database password using KMS
db_password=$(echo $encrypted_password_base64 | base64 --decode | aws kms decrypt --ciphertext-blob fileb:///dev/stdin --output text --query Plaintext | base64 --decode)

# Write the Flask app
cat <<EOF > /home/ec2-user/app.py
from flask import Flask
import psycopg2

app = Flask(__name__)

@app.route("/")
def hello():
    conn = psycopg2.connect(
        dbname="${db_name}",
        user="${db_user}",
        password="${db_password}",
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

# Start the Flask app
python3 /home/ec2-user/app.py &
