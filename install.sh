#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${yellow}mistake:${plain} This script must be run as root!\n" && exit 1

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
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Failed to detect schema, use default schema: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64). If the detection is incorrect, please contact the author"
    exit -1
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
        echo -e "${yellow}Please use CentOS 7 or higher ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${yellow}Please use Ubuntu 20 or higher ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${yellow}Please use Debian 8 or higher version of the system ${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"ubuntu" ]]; then
        apt install wget curl tar -y
        apt install curl socat -y
        apt install nano -y
        snap install core; sudo snap refresh core
    else
       yum install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, you need to forcefully change the port and account password after the installation or update is completed.${plain}"
    read -p "Confirm to continue?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Please set the panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm settings, setting:${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} -port ${config_port}
        echo -e "${green}Account password setting completed${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${green}Panel port setting completed${plain}"
        echo -e "${green}Panel account name setting completed${plain}"
        echo -e "${green}Name and password have been confirmed and registered. Thank you${plain}"
        

    else
        echo -e "${red}Canceled, all settings are default settings, please modify them in time${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/mostafaprohub/V2rayWeb/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect the x-ui version. It may be that the Github API limit is exceeded. Please try again later, or manually specify the x-ui version for installation.${plain}"
            exit 1
        fi
        echo -e "Latest version of x-ui detected: ${last_version}，Start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/mostafaprohub/V2rayWeb/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui, please make sure your server can download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/mostafaprohub/V2rayWeb/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Start installing x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui v$1 Failed, please make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/mostafaprohub/V2rayWeb/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "If it is a new installation, the default web port is ${yellow}54321${plain}，The default username and password are ${yellow}admin${plain}"
    #echo -e "Please make sure that this port is not occupied by other programs，${yellow}and make sure 54321 Port has been released${plain}"
    #    echo -e "If you want to modify 54321 to another port, enter the x-ui command to modify it. Also make sure that the port you modify is also allowed"
    #echo -e ""
    #echo -e "If updating the panel, access the panel as you did before"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} The installation is complete and the panel is started，"
    echo -e ""
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
    echo "12.x-ui geo           Update  geo data"
    echo "13.x-ui uninstall     Uninstall panel"
    echo " "
}

echo -e "${green}Start installation ... ${plain}"
install_base
install_x-ui $1
