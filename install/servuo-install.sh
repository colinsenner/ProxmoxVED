#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: [YourUserName]
# License: MIT | https://github.com/--full/ProxmoxVED/raw/main/LICENSE
# Source: [SOURCE_URL]

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os
msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  git \
  dotnet-sdk-8.0
msg_ok "Installed Dependencies"

msg_info "Cloning ServUO"
$STD git clone --depth 1 https://github.com/ServUO/ServUO.git /opt/servuo
msg_ok "Cloned ServUO"

msg_info "Building ServUO"
cd /opt/servuo
$STD dotnet build -c Release
msg_ok "Built ServUO"
