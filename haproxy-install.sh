#!/usr/bin/env bash
#################################################
####    Govind Kumar
####    Used for HaProxy installation
#################################################

#!/bin/bash
set -o pipefail

function haproxy() {

    if [ systemctl is-active haproxy.service == 'active' ]; then
        
        echo "Haproxy is active"
    
    else

    sudo setenforce 0
    sudo sed -i 's/permissive/disabled/' /etc/sysconfig/selinux
    port=3306

    dnf install epel-release -y
    dnf update -y
    dnf install haproxy -y
    cat >/etc/haproxy/haproxy.cfg <<-'EOF'
    global
        log         127.0.0.1 local2

        chroot      /var/lib/haproxy
        pidfile     /var/run/haproxy.pid
        maxconn     4000
        user        haproxy
        group       haproxy
        daemon
        stats socket /var/lib/haproxy/stats
        ssl-default-bind-ciphers PROFILE=SYSTEM
        ssl-default-server-ciphers PROFILE=SYSTEM
    defaults
        mode                    http
        log                     global
        option                  httplog
        option                  dontlognull
        option http-server-close
        option forwardfor       except 127.0.0.0/8
        option                  redispatch
        retries                 3
        timeout http-request    10s
        timeout queue           1m
        timeout connect         10s
        timeout client          1m
        timeout server          1m
        timeout http-keep-alive 10s
        timeout check           10s
        maxconn                 3000
    frontend stats
            bind *:8089
            mode http
            stats enable
            stats show-node
            stats hide-version
            stats uri /
            stats refresh 10s

    listen  mariadb_multi
            bind *:3306
          # maxconn 200
            mode tcp
            option mysql-check user haproxy
            balance roundrobin
	EOF

    echo "Put Mariadb server IP Adress like:- IP1<space>IP2<space>IP3...,etc."
    read ip
    list=(${ip})

    for host in ${list[@]}
    do
    echo "  server ${host} ${host}:${port} weight 1 maxconn 300 check" | sudo tee -a /etc/haproxy/haproxy.cfg
    done

    systemctl daemon-reload
    systemctl enable --now haproxy
    systemctl restart haproxy
    
    fi
}

function radius() {

    if [ systemctl is-active radius.service == 'active' ]; then

        echo "Radius is active"
    else

    echo "Radius Server Installation inprocessing..."
    dnf --enablerepo=crb install freeradius freeradius-utils freeradius-mysql freeradius-perl -y
    #dnf install mysqltune -y
    firewall-cmd --add-service=radius --permanent >/dev/null
    firewall-cmd --add-service=mysql --permanent >/dev/null
    firewall-cmd --reload   
    
    fi
}

function keepalived() {

    if [ systemctl is-active keepalived.service == 'active' ]; then
    
        echo "Keepalived service is active"
    
    else

    echo "Keepalived Installation inprocessing..."

    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    dnf install keepalived screen -y
    firewall-cmd --add-protocol=vrrp --permanent
    firewall-cmd --reload

    read -p "Server MASTER/BACKUP: " TYPE
    read -p "Server VIP: " VIP
    read -p "Server vrrp_instance [both server should be same]: " vrrp_instance

    if [ "$TYPE" == "BACKUP"]; then
        priority=199
    elif [ "$TYPE" == 'MASTER']; then
        priority=200
    fi

	cat >/etc/keepalived/keepalived.conf <<-'EOT'
    
    ! Configuration File for keepalived
    global_defs {
        enable_script_security
        script_user root
    }

    vrrp_script chk_status {
    script "killall -0 haproxy"
    interval 2
    weight 2
    }

    vrrp_instance VI_${vrrp_instance} {
        state ${TYPE}
        priority ${priority}
        advert_int 1
        virtual_router_id 132
        interface bridge0

    virtual_ipaddress {
        ${VIP}
    }

    track_script {
            chk_status
        }

    }

	EOT

    systemctl enable --now keepalived.service

    fi
}


haproxy
radius
keepalived
