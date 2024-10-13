#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# consts for geo update
PATH_FOR_GEO_IP='/usr/local/x-ui/bin/geoip.dat'
PATH_FOR_CONFIG='/usr/local/x-ui/bin/config.json'
PATH_FOR_GEO_SITE='/usr/local/x-ui/bin/geosite.dat'
URL_FOR_GEO_IP='https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat'
URL_FOR_GEO_SITE='https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Error: This script must be run as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    LOGE "System version not detected, please contact the script author!\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        LOGE "Please use CentOS 7 or higher!\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Please use Ubuntu 16 or higher!\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Please use Debian 8 or higher version of the system!\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart the panel, restarting the panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/mostafaprohub/V2RAYWEB/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force reinstall the latest version without losing data. Do you want to continue?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Canceled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/mostafaprohub/V2RAYWEB/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "The update is complete and the panel has been automatically restarted. "
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel? Xray will also be uninstalled?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "The uninstallation is successful. If you want to delete this script, exit the script and run ${green}rm /usr/bin/x-ui -f${plain} Delete"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset your username and password to admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Username and password have been reset to ${green}admin${plain}，Please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings? Account data will not be lost and username and password will not be changed." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All panel settings have been reset to default values. Now please restart the panel and use the default ${green}54321${plain} Port access panel"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Enter port number[400-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Canceled"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "After setting the port, please restart the panel and use the newly set port. ${green}${port}${plain} Access panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "The panel is already running and does not need to be started again. If you need to restart, please select Restart."
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui Started successfully"
        else
            LOGE "The panel failed to start. It may be because the startup time exceeded two seconds. Please check the log information later."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "The panel has been stopped and does not need to be stopped again"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui and xray stopped successfully"
        else
            LOGE "The panel failed to stop, possibly because the stop time exceeded two seconds. Please check the log information later."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui and xray restarted successfully"
    else
        LOGE "The panel restart failed, possibly because the startup time exceeded two seconds. Please check the log information later."
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui settings start automatically at boot successfully"
    else
        LOGE "x-ui failed to set up auto-start at boot"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui cancels boot and auto-start successfully"
    else
        LOGE "x-ui failed to cancel boot auto-start"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    LOGE " download and install BBR script is successful "
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/mostafaprohub/V2RAYWEB/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Failed to download the script, please check whether the machine can connect to Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "The upgrade script is successful, please re-run the script." && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "The panel has been installed, please do not install it again"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Please install the panel first"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Panel status: ${green}Already run${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Panel status: ${yellow}Not running${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Panel status: ${red}Not installed${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start automatically at boot: ${green}enabled automatically at boot${plain}"
    else
        echo -e "Whether to start automatically at boot: ${red}not enabled automatically at boot${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}xray is running${plain}"
    else
        echo -e "xray status: ${red}xray Not running${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Instructions for use******"
    LOGI "This script will use Acme script to apply for a certificate. When using it, you need to ensure:"
    LOGI "1.Know your Cloudflare registration email"
    LOGI "2.Know the Cloudflare Global API Key"
    LOGI "3.The domain name has been resolved to the current server through Cloudflare"
    LOGI "4.The default installation path for this script to apply for a certificate is the /root/cert directory."
    confirm "I have confirmed the above?[y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Install Acme script"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Installation of acme script failed"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Please set the domain name:"
        read -p "Input your domain here:" CF_Domain
        LOGD "Your domain name is set to:${CF_Domain}"
        LOGD "Please set API key:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "Your API key is:${CF_GlobalKey}"
        LOGD "Please set up your registration email:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "Your registered email is:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Modifying the default CA to Lets'Encrypt failed and the script exited."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Certificate issuance failed and the script exited"
            exit 1
        else
            LOGI "Certificate issued successfully, please wait for installing..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Certificate installation failed and the script exited"
            exit 1
        else
            LOGI "Certificate installation is successful, please wait for automatic update is enabled..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Automatic update settings failed and the script exited"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "The certificate has been installed and automatic update has been turned on. The specific information is as follows"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

#add for cron jobs,including sync geo data,check logs and restart x-ui
cron_jobs() {
    clear
    echo -e "
  ${white}x-ui cron jobs${plain}
  ${white}0.${plain}  return main menu
  ${white}1.${plain}  enable automatically update geo data
  ${white}2.${plain}  disable automatically update geo data 
  ${white}3.${plain}  enable automatically clear xray log
  ${white}4.${plain}  disable automatically clear xray log
  "
    echo && read -p "Please select an option [0-4]: " num
    case "${num}" in
    0)
        show_menu
        ;;
    1)
        enable_auto_update_geo
        ;;
    2)
        disable_auto_update_geo
        ;;
    3)
        enable_auto_clear_log
        ;;
    4)
        disable_auto_clear_log
        ;;
    *)
        LOGE "Please select a valid choice [0-4]"
        ;;
    esac
}

#update geo data
update_geo() {
    #back up first
    mv ${PATH_FOR_GEO_IP} ${PATH_FOR_GEO_IP}.bak
    #update data
    curl -s -L -o ${PATH_FOR_GEO_IP} ${URL_FOR_GEO_IP}
    if [[ $? -ne 0 ]]; then
        echo "Update geoip.dat failed"
        mv ${PATH_FOR_GEO_IP}.bak ${PATH_FOR_GEO_IP}
    else
        echo "Update geoip.dat succeed"
        rm -f ${PATH_FOR_GEO_IP}.bak
    fi
    mv ${PATH_FOR_GEO_SITE} ${PATH_FOR_GEO_SITE}.bak
    curl -s -L -o ${PATH_FOR_GEO_SITE} ${URL_FOR_GEO_SITE}
    if [[ $? -ne 0 ]]; then
        echo "Update geosite.dat failed"
        mv ${PATH_FOR_GEO_SITE}.bak ${PATH_FOR_GEO_SITE}
    else
        echo "Update geosite.dat succeed"
        rm -f ${PATH_FOR_GEO_SITE}.bak
    fi
    #restart x-ui
    systemctl restart x-ui
}

enable_auto_update_geo() {
    LOGI "Enable automatically update geo data..."
    crontab -l >/tmp/crontabTask.tmp
    echo "00 4 */2 * * x-ui geo > /dev/null" >>/tmp/crontabTask.tmp
    crontab /tmp/crontabTask.tmp
    rm /tmp/crontabTask.tmp
    LOGI "Enable automatically update geo data succeed"
}

disable_auto_update_geo() {
    crontab -l | grep -v "x-ui geo" | crontab -
    if [[ $? -ne 0 ]]; then
        LOGI "Cancel x-ui automatically update geo data failed"
    else
        LOGI "Cancel x-ui automatically update geo data succeed"
    fi
}

#clear xray log,need enable log in config template
#here we need input an absolute path for log
clear_log() {
    LOGI "Clear xray logs..."
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        LOGE "Invalid file path,will exit"
        exit 1
    fi
    LOGI "Log file:${filePath}"
    if [[ ! -f ${filePath} ]]; then
        LOGE "Clear xray log failed,${filePath} didn't exist,Please check it"
        exit 1
    fi
    fileSize=$(ls -la ${filePath} --block-size=M | awk '{print $5}' | awk -F 'M' '{print$1}')
    if [[ ${fileSize} -gt ${DEFAULT_LOG_FILE_DELETE_TRIGGER} ]]; then
        rm $1
        if [[ $? -ne 0 ]]; then
            LOGE "Clear xray log :${filePath} Failed"
        else
            LOGI "Clear xray log :${filePath} Succeed"
            systemctl restart x-ui
        fi
    else
        LOGI "Current size of xray log is:${fileSize}M,smaller that ${DEFAULT_LOG_FILE_DELETE_TRIGGER}M,won't clear"
    fi
}

#enable auto delete log，need file path as
enable_auto_clear_log() {
    LOGI "Enable automatically clear xray logs..."
    local accessfilePath=''
    local errorfilePath=''
    accessfilePath=$(cat ${PATH_FOR_CONFIG} | jq .log.access | tr -d '"')
    errorfilePath=$(cat ${PATH_FOR_CONFIG} | jq .log.error | tr -d '"')
    if [[ ! -n ${accessfilePath} && ! -n ${errorfilePath} ]]; then
        LOGI "Current configuration didn't set valid logs,will exited"
        exit 1
    fi
    if [[ -f ${accessfilePath} ]]; then
        crontab -l >/tmp/crontabTask.tmp
        echo "30 4 */2 * * x-ui clear ${accessfilePath} > /dev/null" >>/tmp/crontabTask.tmp
        crontab /tmp/crontabTask.tmp
        rm /tmp/crontabTask.tmp
        LOGI "Enable automatically clear xray log:${accessfilePath} succeed"
    else
        LOGE "Accesslog didn't existed,won't automatically clear it"
    fi

    if [[ -f ${errorfilePath} ]]; then
        crontab -l >/tmp/crontabTask.tmp
        echo "30 4 */2 * * x-ui clear ${errorfilePath} > /dev/null" >>/tmp/crontabTask.tmp
        crontab /tmp/crontabTask.tmp
        rm /tmp/crontabTask.tmp
        LOGI "Enable automatically clear xray log:${errorfilePath} succeed"
    else
        LOGE "Errorlog didn't existed,won't automatically clear it"
    fi
}

#disable auto dlete log
disable_auto_clear_log() {
    crontab -l | grep -v "x-ui clear" | crontab -
    if [[ $? -ne 0 ]]; then
        LOGI "Cancel  automatically clear xray logs failed"
    else
        LOGI "Cancel  automatically clear xray logs succeed"
    fi
}

show_usage() {
    echo "How to use x-ui management script: "
    echo "${yellow}Please choose a code from the numbers below "
    echo "code                  Description "
    echo " "
    echo "1.x-ui                min menu script (more functions)"
    echo "2.x-ui start          Start panel"
    echo "3.x-ui stop           Stop panel"
    echo "4.x-ui restart        Restart panel"
    echo "5.x-ui status         View status"
    echo "6.x-ui enable         start automatically at boot"
    echo "7.x-ui disable        Cancel auto start at boot"
    echo "8.x-ui log            View log"
    echo "9.x-ui v2-ui          Migrate the v2-ui account data of this machine to x-ui"
    echo "10.x-ui update        Update panel"
    echo "11.x-ui install       Install panel"
    echo "12.x-ui geo           Update x-ui geo "
    echo "13.x-ui uninstall     Uninstall panel"
    echo "14.x-ui cron          Cron x-ui jobs"
    echo " "
}

show_menu() {
    echo -e "
  ${green} Thank you for your choice. Please choose one of the management panel V2RAY options:${plain}
  ${white}0.${plain}  Exit script
————————————————
  ${white}1.${plain}  Install x-ui
  ${white}2.${plain}  Update x-ui
  ${white}3.${plain}  Uninstall x-ui
————————————————
  ${white}4.${plain}  Reset username and password
  ${white}5.${plain}  Reset panel settings
  ${white}6.${plain}  Set panel port
  ${white}7.${plain}  View current panel settings
————————————————
  ${white}8.${plain}  Start x-ui
  ${white}9.${plain}  Stop x-ui
  ${white}10.${plain} Restart x-ui
  ${white}11.${plain} View x-ui status
  ${white}12.${plain} View x-ui log
————————————————
  ${white}13.${plain} Set x-ui to start automatically at boot
  ${white}14.${plain} Cancel x-ui auto-start at boot
————————————————
  ${white}15.${plain} recommended: installation BBR   Info: Last updated
  ${white}16.${plain} recommended: Key to apply for SSL certificate  Info: Acme application
  ${white}17.${plain} recommended: x-ui cron jobs
 "
    show_status
    echo && read -p "Please enter your choice [0-17]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    17)
        check_install && cron_jobs
        ;;
    *)
        LOGE "Please enter the correct number [0-17]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "geo")
        check_install 0 && update_geo
        ;;
    "cron")
        check_install && cron_jobs
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
