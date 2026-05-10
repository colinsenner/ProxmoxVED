#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/colinsenner/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: colinsenner
# License: MIT | https://github.com/colinsenner/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ServUO/ServUO

APP="ServUO"
var_tags="${var_tags:-ultima-online;uo;game-server}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_ok "No update script available for ${APP}."
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo ""
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Next steps:${CL}"
echo -e "${INFO}${YW} 1. Download the official UO Classic client:${CL}"
echo -e "${INFO}${YW}    https://uo.com/client-download/${CL}"
echo -e "${INFO}${YW} 2. Run UO.exe from the downloaded client to patch${CL}"
echo -e "${INFO}${YW} 3. Download a modern UO client which will allow you to connect to unofficial servers:${CL}"
echo -e "${INFO}${YW}    https://www.classicuo.eu/${CL}"
echo -e "${INFO}${YW} 4. Add a profile in the modern client: ${CL}"
echo -e "${TAB}${GATEWAY}${BGN}  ${IP} Port: 2593${CL}"
echo -e "${INFO}${YW} 5. Connect to the server${CL}"
echo -e "${INFO}${YW} 6. Enter the console command ${GN}[admin${CL}"
echo -e "${INFO}${YW} 7. Goto ${GN}ADMINISTER -> World Building -> Create World. To populate the world.${CL}"
