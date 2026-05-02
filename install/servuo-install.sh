#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: colinsenner
# License: MIT | https://github.com/colinsenner/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ServUO/ServUO

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt install -y git curl wget zlib1g mono-complete make
msg_ok "Installed Dependencies"

# dotnet
msg_info "Installing dotnet SDK"
$STD wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
$STD sudo dpkg -i packages-microsoft-prod.deb
$STD rm packages-microsoft-prod.deb
$STD apt update && apt install -y dotnet-sdk-10.0
msg_ok "Installed dotnet SDK"

msg_info "Cloning ServUO"
$STD git clone --depth 1 https://github.com/ServUO/ServUO.git /opt/servuo
msg_ok "Cloned ServUO"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/servuo.service
[Unit]
Description=ServUO Ultima Online Server
After=network.target

[Service]
WorkingDirectory=/opt/servuo
ExecStart=/usr/bin/dotnet /opt/servuo/publish/ServUO.dll
Restart=always

[Install]
WantedBy=multi-user.target
EOF
# systemctl enable -q --now servuo.service
msg_ok "Created Service"

msg_info "Building ServUO"
$STD cd /opt/servuo
$STD make build

msg_ok "Built ServUO"
$STD make run
msg_ok "Running ServUO"

motd_ssh
customize

cat >>/etc/motd <<EOF

 ServUO Port: 2593
 Docs: https://github.com/ServUO/ServUO/wiki
EOF

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned up"
