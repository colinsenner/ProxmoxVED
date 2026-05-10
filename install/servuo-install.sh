#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: colinsenner
# License: MIT | https://github.com/colinsenner/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ServUO/ServUO

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
catch_errors
setting_up_container
network_check
update_os

# Wine environment for interactive shells and child scripts
cat >~/uo-env.sh <<'EOF'
export WINEPREFIX=/opt/uo/.wine
export WINEARCH=win32
EOF
echo "source ~/uo-env.sh" >>~/.bashrc
source ~/.bashrc

msg_info "Installing Dependencies"
$STD dpkg --add-architecture i386
$STD apt update
$STD apt install -y git mono-complete zlib1g make wine wine32 xvfb xdotool inotify-tools
msg_ok "Installed Dependencies"

# Mono looks for libz.so
ln -s /usr/lib/x86_64-linux-gnu/libz.so.1 /usr/lib/x86_64-linux-gnu/libz.so

# dotnet
msg_info "Installing dotnet SDK"
$STD wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
$STD sudo dpkg -i packages-microsoft-prod.deb
$STD rm packages-microsoft-prod.deb
$STD apt update
$STD apt install -y dotnet-sdk-10.0
msg_ok "Installed dotnet SDK"

#
# UO Classic Installation and Patching
#
msg_info "Downloading UO Client Files"
$STD mkdir -p /opt/uo && chown $(whoami):$(whoami) /opt/uo
cd /opt/uo
$STD wget http://web.cdn.eamythic.com/us/uo/installers/20120309/UOClassicSetup_7_0_24_0.exe

# For some reason the installer doesn't respect /S /NCRC /D=... So we send the keystrokes manually
cat >install_uo.sh <<'EOF'
#!/usr/bin/env bash
source ~/uo-env.sh
cd /opt/uo

wine UOClassicSetup_7_0_24_0.exe &
WINE_PID=$!

sleep 30  # Screen 1: Next
xdotool key alt+n
sleep 10  # Screen 2: Accept license
xdotool key alt+a
sleep 10  # Screen 3: Next
xdotool key alt+n
sleep 10  # Screen 4: Install
xdotool key alt+i
sleep 60  # Wait for install to complete, then Finish
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
msg_info "Patching UO to generate .mul files (Patience)..."
cd "/opt/uo/.wine/drive_c/Program Files/Electronic Arts/Ultima Online Classic"

# Run the UO.exe to patch the game
$STD xvfb-run wine UO.exe &

PATCH_TIMEOUT=1800
PATCH_ELAPSED=0
PATCH_SUCCESS=false

while [ $PATCH_ELAPSED -lt $PATCH_TIMEOUT ]; do
  for log in "/opt/uo/.wine/drive_c/Program Files/Electronic Arts/Ultima Online Classic"/logs/patcher.*.Log; do
    if [ -f "$log" ] && grep -qa "Patch Operation Complete" "$log"; then
      PATCH_SUCCESS=true
      break 2
    fi
  done
  sleep 5
  PATCH_ELAPSED=$((PATCH_ELAPSED + 5))
done

if [ "$PATCH_SUCCESS" != "true" ]; then
  msg_error "UO patching timed out. You can manually copy all *.mul files from a patched UO Classic install to /opt/ServUO/UO_DATA."
  exit 1
fi
msg_ok "UO patching completed"

msg_info "Downloading ServUO"
$STD git clone --depth 1 https://github.com/ServUO/ServUO.git /opt/ServUO
msg_ok "Downloaded ServUO"

$STD mkdir -p /opt/ServUO/UO_DATA
$STD cp "/opt/uo/.wine/drive_c/Program Files/Electronic Arts/Ultima Online Classic"/*.mul /opt/ServUO/UO_DATA/
msg_ok "Copied UO Client Files to /opt/ServUO/UO_DATA"

msg_ok "Creating owner account"
read -r -p "Username [default: admin]: " ACCOUNT_USER
ACCOUNT_USER=${ACCOUNT_USER:-admin}
echo -n "Password [default: admin]: "
read -rs ACCOUNT_PASS
ACCOUNT_PASS=${ACCOUNT_PASS:-admin}
echo ""
read -r -p "Enter shard name [default: My Shard]: " SHARD_NAME
SHARD_NAME=${SHARD_NAME:-My Shard}
msg_ok "Owner account: ${ACCOUNT_USER}"
msg_ok "Shard name:    ${SHARD_NAME}"

# Configure ServUO
$STD sed -i "s|^#CustomPath=.*|CustomPath=/opt/ServUO/UO_DATA|" /opt/ServUO/Config/DataPath.cfg
msg_ok "Set the custom path in ServUO"
$STD sed -i "s|^Name=.*|Name=${SHARD_NAME}|" /opt/ServUO/Config/Server.cfg
msg_ok "Set shard name in Server.cfg"
$STD sed -i "s|AccountsPerIp=.*|AccountsPerIp=10|" /opt/ServUO/Config/Accounts.cfg
msg_ok "Set AccountsPerIp to 10 in Accounts.cfg"
$STD sed -i "s|PasswordCommandEnabled=.*|PasswordCommandEnabled=True|" /opt/ServUO/Config/Accounts.cfg
msg_ok "Enabled [password command in Accounts.cfg"

# Create owner account
CRYPT_PASS=$(echo -n "${ACCOUNT_USER}${ACCOUNT_PASS}" | sha1sum | head -c 40 | tr '[:lower:]' '[:upper:]' | sed 's/../&-/g;s/-$//')
mkdir -p /opt/ServUO/Saves/Accounts
cat >/opt/ServUO/Saves/Accounts/accounts.xml <<EOF
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<accounts count="1">
        <account>
                <username>${ACCOUNT_USER}</username>
                <newCryptPassword>${CRYPT_PASS}</newCryptPassword>
                <accessLevel>Owner</accessLevel>
                <created>2026-01-01T00:00:00.000000Z</created>
                <lastLogin>2026-01-01T00:00:00.000000Z</lastLogin>
                <totalGameTime>PT8.39915S</totalGameTime>
                <totalCurrency>1000000</totalCurrency>
                <sovereigns>1000000</sovereigns>
        </account>
</accounts>
EOF

msg_info "Building ServUO"
cd /opt/ServUO
$STD printf "y\n%s\n%s\n" "$ACCOUNT_USER" "$ACCOUNT_PASS" | $STD make build
msg_ok "Built ServUO"

cat <<'EOF' >/etc/systemd/system/servuo.service
[Unit]
Description=ServUO Ultima Online Server
After=network.target
StartLimitInterval=200
StartLimitBurst=5

[Service]
WorkingDirectory=/opt/ServUO
ExecStart=mono ServUO.exe
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Created service file"

# Enable the service
systemctl enable -q --now servuo.service
msg_ok "Started ServUO service"

# Cleanup
pkill UO.bin || true

motd_ssh
customize
cleanup_lxc
