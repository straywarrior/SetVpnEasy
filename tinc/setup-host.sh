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
install_tinc(){
    local system=` lsb_release -i -s | tr '[A-Z]' '[a-z]' `
    printf "[INFO]Current system type: ${system}\n"
    printf "${YELLOW}[INFO]Install tinc ...\n${NC}"
    case "$system" in
        *ubuntu*)
            apt-get install tinc -y
            ;;
        *centos*)
            yum install tinc -y
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
    remote_servers=${*:5}
    printf "\nTinc configuration:\n"
    printf "${YELLOW}|PrivNetwork: \t$1\n|Hostname: \t$2\n|Domain: \t$3 \n|PrivateIP: \t$4\n"
    printf "|ConnectTo: \t${remote_servers}\n${NC}\n"
    printf "Confirm the configuration above [y/N]:"
    read confirm
    if [ "$confirm" != "y" -a "$confirm" != "Y" ]; then
        return
    fi
    local privnet_name=$1
    local host_name=$2
    local main_domain=$3
    local private_ip=$4
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
    printf "Address = ${host_name}.${main_domain}\nPort = 655" \
        > ${conf_prefix}/hosts/${host_name}

    printf "[INFO]Generate Key-Pairs ...\n"
    printf "\n" | tincd -n ${privnet_name} -K
    mv ${conf_prefix}/rsa_key.priv ${conf_prefix}/keys/${host_name}.priv

    printf "[INFO]Generate tinc-up & tinc-down\n"
    printf "#!/bin/sh\nifconfig \$INTERFACE ${private_ip} netmask 255.255.255.0\n" \
        > ${conf_prefix}/tinc-up
    printf "#/bin/sh\nifconfig \$INTERFACE down" \
        > ${conf_prefix}/tinc-down

    printf "[INFO]Tinc Configuration Done.\n"
}

print_help(){
    cat <<EOF
usage: setup-host.sh <--privnet-name privnet_name> <--host-name host_name>
                     <--main-domain main_domain> <--private-ip private_ip>
                     [--connect-to remote-host1 ...]
                     [--try-install-tinc]

EOF
    printf "${YELLOW}warning: You should have root privilege to run this configuration script.${NC}\n"
    exit
}

## Main process
need_install_tinc=false
if [ $# -lt 8 ]; then
    print_help
fi

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

echo "[INFO]Process start..."

if [ $need_install_tinc == true ]; then
    install_tinc
fi
configure_tinc $privnet_name $host_name $main_domain $private_ip $remotes

echo "[INFO]All process done."