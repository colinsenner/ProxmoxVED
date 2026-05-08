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

# We have to do several things to get this working
# 1. Install and run UO Classic to generate the .mul files, by patching it to the latest version
# 2. Copy the .mul files to the ServUO directory, and set the custom path in the ServUO config
# 3. Build and run ServUO

# Application specific directories
APP_DIR="/opt/ServUO"
UO_DIR="/opt/uo"
UO_CLASSIC_DIR="${UO_DIR}/drive_c/Program Files/Electronic Arts/Ultima Online Classic"
UO_DATA_DIR="${APP_DIR}/UO_DATA"
DATAPATH_CONFIG="${APP_DIR}/Config/DataPath.cfg"

# Wine variables
export UO_DIR
export UO_CLASSIC_DIR
export WINEPREFIX="${UO_DIR}"
export WINEARCH=win32

msg_info "Installing Dependencies"
$STD dpkg --add-architecture i386
$STD apt update
$STD apt install -y git curl wget zlib1g mono-complete make libz-dev wine wine32 xvfb xdotool inotify-tools
msg_ok "Installed Dependencies"

#
# UO Classic Installation and Patching
#
msg_info "Downloading UO Client Files"
$STD mkdir -p ${UO_DIR} && chown $(whoami):$(whoami) ${UO_DIR}
$STD cd ${UO_DIR}
$STD wget http://web.cdn.eamythic.com/us/uo/installers/20120309/UOClassicSetup_7_0_24_0.exe

msg_info "Creating automated installer script"
# For some reason the installer doesn't respect /S /NCRC /D=... So we send the keystrokes manually
cat >install_uo.sh <<EOF
#!/usr/bin/env bash

wine UOClassicSetup_7_0_24_0.exe &
WINE_PID=\$!

sleep 10  # Screen 1: Next
xdotool key alt+n
sleep 5  # Screen 2: Accept license
xdotool key alt+a
sleep 5  # Screen 3: Next
xdotool key alt+n
sleep 5  # Screen 4: Install
xdotool key alt+i
sleep 30  # Wait for install to complete, then Finish
xdotool key alt+f

echo "Install complete!"
EOF

chmod +x install_uo.sh
msg_info "Installing UO Classic Game Files"
$STD xvfb-run ./install_uo.sh
msg_ok "Installed UO Classic Game Files"

#
# Patching UO Classic to generate .mul files
#
msg_info "Patching UO to the latest version. This can take a while..."

# Create patch_uo.sh script — just runs the UO patcher under Wine
cat >patch_uo.sh <<'EOF'
#!/usr/bin/env bash
cd "${UO_CLASSIC_DIR}"
wine UO.exe
EOF

chmod +x patch_uo.sh
SENTINEL_GLOB="${UO_CLASSIC_DIR}/logs/patcher.*.Log"

msg_info "Patching UO to generate .mul files"
$STD xvfb-run ./patch_uo.sh &
PATCH_PID=$!

inotifywait -r -e close_write,create \
  --format '[%T] %w%f' --timefmt '%H:%M:%S' \
  "${UO_CLASSIC_DIR}" 2>/dev/null &
INOTIFY_PID=$!

TIMEOUT=1800
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  if compgen -G "$SENTINEL_GLOB" >/dev/null 2>&1; then
    msg_info "UO patcher log detected, waiting a few seconds for patching to complete..."
    sleep 3
    break
  fi
  if ! kill -0 $PATCH_PID 2>/dev/null; then
    kill $INOTIFY_PID 2>/dev/null
    wait $INOTIFY_PID 2>/dev/null
    msg_error "UO patcher exited unexpectedly before patching completed"
    exit 1
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done

kill $PATCH_PID $INOTIFY_PID 2>/dev/null
wait $PATCH_PID $INOTIFY_PID 2>/dev/null

if [ $ELAPSED -ge $TIMEOUT ]; then
  msg_error "Timeout reached waiting for UO patcher to complete"
  exit 1
fi

msg_ok "UO patching completed"

# dotnet
# msg_info "Installing dotnet SDK"
# $STD wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
# $STD sudo dpkg -i packages-microsoft-prod.deb
# $STD rm packages-microsoft-prod.deb
# $STD apt update && apt install -y dotnet-sdk-10.0
# msg_ok "Installed dotnet SDK"

# msg_info "Cloning ServUO"
# $STD git clone --depth 1 https://github.com/ServUO/ServUO.git ${APP_DIR}
# msg_ok "Cloned ServUO"

# msg_info "Copying UO Client Files to ${UO_DATA_DIR}"
# $STD mkdir ${UO_DATA_DIR}
# $STD cp "/opt/uo/drive_c/Program\ Files/Electronic\ Arts/Ultima\ Online\ Classic/*.mul" ${UO_DATA_DIR}/
# msg_ok "Copied UO Client Files"

# msg_info "Setting the custom path in ServUO ${DATAPATH_CONFIG}"
# $STD sed -i "s|^#CustomPath=.*|CustomPath=${UO_DATA_DIR}|" ${DATAPATH_CONFIG}

# msg_info "Creating Service"
# cat <<EOF >/etc/systemd/system/servuo.service
# [Unit]
# Description=ServUO Ultima Online Server
# After=network.target

# [Service]
# WorkingDirectory=${APP_DIR}
# ExecStart=/usr/bin/mono ${APP_DIR}/ServUO.exe
# Restart=always

# [Install]
# WantedBy=multi-user.target
# EOF

# systemctl enable -q --now servuo.service
# msg_ok "Created Service"

# msg_info "Building ServUO"
# $STD cd ${APP_DIR}
# $STD make build release
# msg_ok "Built ServUO"

# motd_ssh
# customize

# cat >>/etc/motd <<EOF

#  ServUO Port: 2593
#  Docs: https://github.com/ServUO/ServUO/wiki
# EOF

# msg_info "Cleaning up"
# $STD apt-get -y autoremove
# $STD apt-get -y autoclean
# msg_ok "Cleaned up"
