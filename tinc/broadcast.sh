#! /bin/bash -e
#
# broadcast.sh
# Copyright (C) 2016 StrayWarrior <i@straywarrior.com>
#
# Distributed under the terms of GPLv3 license
#

main_domain=straywarrior.com
privnet_name=straynet
server_names=
server_ports=
remotes=

YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

## Subprocess
upload_ssh_keys(){
    pub_key=`cat ~/.ssh/id_rsa.pub`
    echo $pub_key
    for i in ${!server_names[*]}
    do
        server=${server_names[i]}
        port=${server_ports[i]}
        printf "${YELLOW}Upload SSH key to: ${server}.${main_domain} ...\n${NC}"
        ssh -p $port root@${server}.${main_domain} \
            "mkdir -p ~/.ssh; chmod 700 ~/.ssh; \
             printf \"${pub_key}\n\" >> ~/.ssh/authorized_keys; \
             chmod 600 ~/.ssh/authorized_keys"
    done
}


get_tinc_hosts(){
    mkdir -p hosts
    for i in ${!server_names[*]}
    do
        server=${server_names[i]}
        port=${server_ports[i]}
        printf "${YELLOW}Get Tinc host configuration from: ${server}.${main_domain} ...\n${NC}"
        scp -p -P $port \
            root@${server}.${main_domain}:/etc/tinc/${privnet_name}/hosts/${server} \
            hosts/
    done
}

put_tinc_hosts(){
    for i in ${!server_names[*]}
    do
        server=${server_names[i]}
        port=${server_ports[i]}
        printf "${YELLOW}Put host configuration to: ${server}.${main_domain} ...\n${NC}"
        scp -p -r -P $port \
            hosts/ \
            root@${server}.${main_domain}:/etc/tinc/${privnet_name}/
    done
}

parse_remote_hosts(){
    for host in ${remotes[*]}
    do
        host_pair=(${host/:/ })
        if [ ${#host_pair[*]} -lt 2 ];then
            host_pair[1]=22
        fi
        server_names="${host_pair[0]} $server_names"
        server_ports="${host_pair[1]} $server_ports"
    done
    server_names=($server_names)
    server_ports=($server_ports)
}

print_help(){
    cat <<EOF
usage: broadcast.sh <--privnet-name privnet_name> <--main-domain main_domain>
                    [--get-hosts] [--put-hosts] [--upload-ssh-keys]
                    [--connect-to hostname[:ssh_port] ...]

EOF
    printf "${YELLOW}warning: You may need root privilege to run this configuration script.${NC}\n"
    exit
}

## Main process
need_upload_ssh_keys=false
need_get_tinc_hosts=false
need_put_tinc_hosts=false

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
        --main-domain)
            main_domain="$2"
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
        --get-hosts)
            need_get_tinc_hosts=true
            ;;
        --put-hosts)
            need_put_tinc_hosts=true
            ;;
        --upload-ssh-keys)
            need_upload_ssh_keys=true
            ;;
        *)
            echo "Unknown option $1"
            print_help
            ;;
    esac
shift
done

if [ ${#privnet_name} -eq 0 -o ${#main_domain} -eq 0 ]; then
    print_help
fi

echo "[INFO]Process start..."
parse_remote_hosts

for action in upload_ssh_keys \
              get_tinc_hosts \
              put_tinc_hosts
do
    eval need_action=\$need_$action
    if [ $need_action == true ]; then
        $action
    fi
done

echo "[INFO]All process done."