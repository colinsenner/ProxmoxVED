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

# Application specific directories
APP_DIR="/opt/ServUO"
UO_DIR="/opt/uo"
UO_DATA_DIR="${APP_DIR}/UO_DATA"
DATAPATH_CONFIG="${APP_DIR}/Config/DataPath.cfg"

msg_info "Installing Dependencies"
$STD dpkg --add-architecture i386
$STD apt update
$STD apt install -y git curl wget zlib1g mono-complete make libz-dev wine wine32 xvfb xdotool
msg_ok "Installed Dependencies"

# UO Client Files
msg_info "Downloading UO Client Files"
$STD mkdir ${UO_DIR} && chown $(whoami):$(whoami) ${UO_DIR}
$STD cd ${UO_DIR}
$STD wget http://web.cdn.eamythic.com/us/uo/installers/20120309/UOClassicSetup_7_0_24_0.exe

msg_info "Creating automated installer script"
# For some reason the installer doesn't respect /S /NCRC /D=... So we send the keystrokes manually
cat >install.sh <<'EOF'
#!/usr/bin/env bash
export WINEPREFIX=/opt/uo/
export WINEARCH=win32

# Start the installer in background
wine UOClassicSetup_7_0_24_0.exe &
WINE_PID=$!

# Screen 1: Next
sleep 10
xdotool key alt+n

# Screen 2: Accept license
sleep 5
xdotool key alt+a

# Screen 3: Next
sleep 5
xdotool key alt+n

# Screen 4: Install
sleep 5
xdotool key alt+i

# Wait for install to complete, then Finish
sleep 30
xdotool key alt+f

wait $WINE_PID
echo "Install complete!"
EOF

chmod +x install.sh
msg_info "Installing UO Classic Game Files"
xvfb-run ./install.sh

msg_ok "Installed UO Classic Game Files"

# dotnet
msg_info "Installing dotnet SDK"
$STD wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
$STD sudo dpkg -i packages-microsoft-prod.deb
$STD rm packages-microsoft-prod.deb
$STD apt update && apt install -y dotnet-sdk-10.0
msg_ok "Installed dotnet SDK"

msg_info "Cloning ServUO"
$STD git clone --depth 1 https://github.com/ServUO/ServUO.git ${APP_DIR}
msg_ok "Cloned ServUO"

msg_info "Copying UO Client Files to ${UO_DATA_DIR}"
$STD mkdir ${UO_DATA_DIR}
$STD cp "/opt/uo/drive_c/Program\ Files/Electronic\ Arts/Ultima\ Online\ Classic/*.mul" ${UO_DATA_DIR}/
msg_ok "Copied UO Client Files"

msg_info "Setting the custom path in ServUO ${DATAPATH_CONFIG}"
$STD sed -i "s|^#CustomPath=.*|CustomPath=${UO_DATA_DIR}|" ${DATAPATH_CONFIG}

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/servuo.service
[Unit]
Description=ServUO Ultima Online Server
After=network.target

[Service]
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/mono ${APP_DIR}/ServUO.exe
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now servuo.service
msg_ok "Created Service"

msg_info "Building ServUO"
$STD cd ${APP_DIR}
$STD make build release
msg_ok "Built ServUO"

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
