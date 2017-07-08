#! /bin/bash -e
#
# setup-host.sh
# Copyright (C) 2016 StrayWarrior <i@straywarrior.com>
#
# Distributed under the terms of GPLv3 license
#

YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'


## Subprocess
check_argument(){
    for arg in $*
    do
        eval arg_value=\$${arg}
        if [ ${#arg_value} -eq 0 ] || [ ${arg_value:0:1} == "-" ]; then
            printf "${RED}Unknown argument value: ${arg_value}${NC}\n"
            print_help
        fi
    done
}

detect_system_type() {
    if (lsb_release > /dev/null 2>&1); then
        system=` lsb_release -i -s | tr '[A-Z]' '[a-z]' `
    elif (cat /etc/redhat-release > /dev/null 2>&1); then
        system=` cat /etc/redhat-release | tr '[A-Z]' '[a-z]' `
    fi
    echo $system
}

install_tinc(){
    system=$(detect_system_type)
    printf "[INFO]Current system type: ${system}\n"
    printf "${YELLOW}[INFO]Install tinc ...\n${NC}"
    case "$system" in
        *ubuntu*)
            apt-get install tinc -y
            ;;
        *centos*)
            yum install epel-release -y
            yum install tinc --enablerepo=epel -y
            ;;
        *debian*)
            apt-get install tinc -y
            ;;
        *)
            printf "${RED}[Error]Unknown system type. Please install tinc by yourself.${NC}"
            exit
            ;;
    esac
}

configure_tinc(){
    local privnet_name=$1
    local host_name=$2
    local main_domain=$3
    local private_ip=$4
    local port=$5
    local remote_servers=${*:6}
    printf "\nTinc configuration:\n"
    printf "${YELLOW}|PrivNetwork:\t${privnet_name}\n"
    printf "|Hostname:\t${host_name}\n"
    printf "|Domain:\t${main_domain} \n"
    printf "|PrivateIP:\t${private_ip}\n"
    printf "|Port:\t\t${port}\n"
    printf "|ConnectTo:\t${remote_servers}\n${NC}\n"
    printf "Confirm the configuration above [y/N]:"
    read confirm
    if [ "$confirm" != "y" -a "$confirm" != "Y" ]; then
        return
    fi

    local conf_prefix=/etc/tinc/${privnet_name}
    mkdir -p ${conf_prefix}
    mkdir -p ${conf_prefix}/hosts
    mkdir -p ${conf_prefix}/keys
    printf "[INFO]Generate tinc.conf ...\n"
    printf "Name = ${host_name}\n\nMode = switch\n\nPrivateKeyFile = ${conf_prefix}/keys/${host_name}.priv\n\n" \
        > ${conf_prefix}/tinc.conf
    for i in ${remote_servers[*]}; do
        printf "ConnectTo = $i\n" >> ${conf_prefix}/tinc.conf
    done

    printf "[INFO]Generate hosts/${host_name} ...\n"
    printf "Address = ${host_name}.${main_domain}\nPort = ${port}" \
        > ${conf_prefix}/hosts/${host_name}

    printf "[INFO]Generate Key-Pairs ...\n"
    printf "\n" | tincd -n ${privnet_name} -K
    mv ${conf_prefix}/rsa_key.priv ${conf_prefix}/keys/${host_name}.priv

    printf "[INFO]Generate tinc-up & tinc-down\n"
    printf "#!/bin/sh\nifconfig \$INTERFACE ${private_ip} netmask 255.255.255.0\n" \
        > ${conf_prefix}/tinc-up
    printf "#/bin/sh\nifconfig \$INTERFACE down" \
        > ${conf_prefix}/tinc-down
    chmod +x ${conf_prefix}/tinc-up ${conf_prefix}/tinc-down

    printf "[INFO]Tinc Configuration Done.\n"
}

enable_ip_forward() {
    printf "[INFO]Try to enable IP forwarding ...\n"
    sysctl -w net.ipv4.ip_forward=1
    if cat /proc/sys/net/ipv4/ip_forward; then
        printf "${RED}Failed to enable IP forwarding${NC}\n"
        exit
    fi
    if grep "net.ipv4.ip_forward" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    else
        printf "To be safe, change /etc/sysctl.conf manually to set net.ipv4.ip_forward = 1\n"
        printf "Suggested command:\n"
        printf "sed -i.backup 's/^.*net.ipv4.ip_forward.*$/net.ipv4.ip_forward = 1/' /etc/sysctl.conf\n"
    fi
    printf "[INFO]IP forwarding enabled\n"
}

print_help(){
    cat <<EOF
usage: setup-host.sh <--privnet-name privnet_name> <--host-name host_name>
                     <--main-domain main_domain> <--private-ip private_ip>
                     [--port port] [--connect-to remote-host1 ...]
                     [--try-install-tinc]

EOF
    printf "${YELLOW}warning: You should have root privilege to run this configuration script.${NC}\n"
    exit
}

## Main process
need_install_tinc=false
privnet_name=
host_name=
main_domain=
private_ip=
port=655

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --help)
            print_help
            ;;
        -h)
            print_help
            ;;
        --privnet-name)
            privnet_name="$2"
            shift
            ;;
        --host-name)
            host_name="$2"
            shift
            ;;
        --main-domain)
            main_domain="$2"
            shift
            ;;
        --private-ip)
            private_ip="$2"
            shift
            ;;
        --port)
            port="$2"
            shift
            ;;
        --connect-to)
            while [[ $# -gt 1 ]]; do
                value=$2
                if [[ ${value:0:1} == "-" ]]; then break; fi;
                remotes="$value $remotes"
                shift
            done
            ;;
        --try-install-tinc)
            need_install_tinc=true
            ;;
        *)
            echo "Unknown option $1"
            print_help
            ;;
    esac
shift
done

check_argument privnet_name host_name main_domain private_ip

echo "[INFO]Process start..."

if [ $need_install_tinc == true ]; then
    install_tinc
fi
configure_tinc $privnet_name $host_name $main_domain $private_ip $port $remotes

echo "[INFO]All process done."
