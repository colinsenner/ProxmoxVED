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
UO_DATA_DIR="${APP_DIR}/UO_DATA"

# Environment variables for setup
cat >~/uo-env.sh <<EOF
export APP_DIR="${APP_DIR}"
export UO_DIR="${UO_DIR}"
export UO_CLASSIC_DIR="${UO_DIR}/drive_c/Program Files/Electronic Arts/Ultima Online Classic"
export UO_DATA_DIR="${UO_DATA_DIR}"
export DATAPATH_CONFIG="${APP_DIR}/Config/DataPath.cfg"
export WINEPREFIX="${UO_DIR}"
export WINEARCH=win32
EOF
echo "source ~/uo-env.sh" >>~/.bashrc
source ~/.bashrc

msg_info "Installing Dependencies"
$STD dpkg --add-architecture i386
$STD apt update
$STD apt install -y git curl wget zlib1g mono-complete make libz-dev wine wine32 xvfb xdotool inotify-tools tmux
msg_ok "Installed Dependencies"

# dotnet
msg_info "Installing dotnet SDK"
$STD wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
$STD sudo dpkg -i packages-microsoft-prod.deb
$STD rm packages-microsoft-prod.deb
$STD apt update && apt install -y dotnet-sdk-10.0
msg_ok "Installed dotnet SDK"

#
# UO Classic Installation and Patching
#
msg_info "Downloading UO Client Files"
$STD mkdir -p ${UO_DIR} && chown $(whoami):$(whoami) ${UO_DIR}
$STD cd ${UO_DIR}
$STD wget http://web.cdn.eamythic.com/us/uo/installers/20120309/UOClassicSetup_7_0_24_0.exe

msg_info "Creating automated installer script"
# For some reason the installer doesn't respect /S /NCRC /D=... So we send the keystrokes manually
cat >install_uo.sh <<'EOF'
#!/usr/bin/env bash
source ~/uo-env.sh

wine UOClassicSetup_7_0_24_0.exe &
WINE_PID=$!

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
msg_info "Patching UO to generate .mul files (this can take up to 30 minutes)..."
cd "$UO_CLASSIC_DIR"

$STD xvfb-run wine UO.exe &
WINE_PID=$!

# Give the user feedback about the patch process, so they know it's working by watching the directory for changes
inotifywait -m -r "$UO_CLASSIC_DIR" --format '%w%f' 2>/dev/null |
  awk '/\.(uop|mul|def|mp3|txt)$/ { if ($0 != last) { print "Patching: " $0; last = $0; fflush() } }' &
INOTIFY_PID=$!

PATCH_TIMEOUT=1800
PATCH_ELAPSED=0
PATCH_SUCCESS=false

while [ $PATCH_ELAPSED -lt $PATCH_TIMEOUT ]; do
  # Check for the patch completion log entry
  for log in "$UO_CLASSIC_DIR"/logs/patcher.*.Log; do
    if [ -f "$log" ] && grep -q "Patch Operation Complete." "$log"; then
      PATCH_SUCCESS=true
      break
    fi
  done

  sleep 5
  PATCH_ELAPSED=$((PATCH_ELAPSED + 5))
done

kill $WINE_PID $INOTIFY_PID 2>/dev/null
wait $WINE_PID $INOTIFY_PID 2>/dev/null || true

if [ "$PATCH_SUCCESS" != "true" ]; then
  msg_error "UO patching timed out. You can manually copy all *.mul files from a patched UO Classic install to ${UO_DATA_DIR}."
  exit 1
fi
msg_ok "UO patching completed"

msg_info "Cloning ServUO"
$STD git clone --depth 1 https://github.com/ServUO/ServUO.git ${APP_DIR}
msg_ok "Cloned ServUO"

msg_info "Copying UO Client Files to ${UO_DATA_DIR}"
$STD mkdir -p ${UO_DATA_DIR}
$STD cp "$UO_CLASSIC_DIR/*.mul" ${UO_DATA_DIR}/
msg_ok "Copied UO Client Files"

msg_info "Setting the custom path in ServUO ${DATAPATH_CONFIG}"
$STD sed -i "s|^#CustomPath=.*|CustomPath=${UO_DATA_DIR}|" ${DATAPATH_CONFIG}

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
