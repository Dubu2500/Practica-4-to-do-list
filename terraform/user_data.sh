#!/bin/bash
set -e

apt-get update -y
apt-get install -y git python3-pip python3-venv

git clone ${repo_url} /opt/todo
python3 -m venv /opt/todo/venv
/opt/todo/venv/bin/pip install -r /opt/todo/src/requirements.txt

cat > /etc/systemd/system/todo.service <<EOF
[Unit]
Description=to-do-list-api
After=network.target

[Service]
WorkingDirectory=/opt/todo/src
ExecStart=/opt/todo/venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now todo
