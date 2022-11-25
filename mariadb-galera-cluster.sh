#!/bin/bash
#########################################################################
# Configure Galera Mariadb cluster setup script for RHEL,Centos,Fedra   #
#               Govind Sharma <govind.sharma@live.com>                  #
#                    GNU GENERAL PUBLIC LICENSE                         #
#                       Version 3, 29 June 2007                         #
#                                                                       #
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>  #
# Everyone is permitted to copy and distribute verbatim copies          #
# of this license document, but changing it is not allowed.             #
#                                                                       #
#########################################################################
set -o pipefail

C='\033[0m'
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
galerafile='/etc/my.cnf.d/galera.cnf'
cluster_name=go_cluster

function mariadb_server_galera(){

    echo -e "${G}Galera Mariadb cluster rpm installation...${C}"
    echo ""
    sudo dnf -y epel-release &>/dev/null
    sudo dnf -y update &>/dev/null
    sudo dnf -y install sshpass &>/dev/null
    sudo dnf -y install mariadb-server-galera &>/dev/null
    firewall
}

function firewall(){

    sudo sudo systemctl enable --now 'firewalld.service'
    sudo firewall-cmd --add-service=mysql --permanent &>/dev/null #(mysql)
    sudo firewall-cmd --add-port=4567/tcp --permanent &>/dev/null #(galera)
    sudo firewall-cmd --add-port=4568/tcp --permanent &>/dev/null #(galera IST tcp)
    sudo firewall-cmd --add-port=4444/tcp --permanent &>/dev/null #(rsync / SST)
    sudo firewall-cmd --add-port=4568/udp --permanent &>/dev/null #(galera IST udp)
    sudo firewall-cmd --add-port=9999/tcp --permanent &>/dev/null #(Must be open on the controller, streaming port for Xtrabackup)
    sudo firewall-cmd --add-port=9200/tcp --permanent &>/dev/null #(HAProxy healthcheck)
    sudo firewall-cmd --reload &>/dev/null
}

function galera_config_master(){
    #Galera configuration
    echo "Galera configuring...."
    sed -i 's/"my_wsrep_cluster"/'${cluster_name}'/' ${galerafile}
    sed -i 's/wsrep_on=0/wsrep_on=ON/' ${galerafile}
    sed -i 's/#wsrep_provider_options=/wsrep_provider_options="gcache.size=2G;gcs.fc_limit=128"/' ${galerafile}
    sed -i 's/"wsrep_slave_threads=1"/"wsrep_slave_threads=48"/' ${galerafile}

    echo "Put Mariadb nodes IP Adress like:- IP1,IP2,IP3...,etc."
    read nodes
    read -p "Put Mariadb Master IP Adress: " wsrep_cluster_address
    read -p "Put Mariadb Master IP HostName: " wsrep_master_name

    if [ "$wsrep_cluster_address" != '' ]; then
        echo "wsrep_cluster_address="gcomm://${wsrep_cluster_address},${nodes}"" | tee -a ${galerafile}
        echo "wsrep_node_address="${wsrep_cluster_address}"" | tee -a ${galerafile}
        echo "wsrep_node_name="${wsrep_master_name}"" | tee -a ${galerafile}
    else 
        echo Please provide required input
        exit 
    fi

}

function galera_config_node(){
    #Galera configuration
    echo "Galera configuring...."
    sed -i 's/"my_wsrep_cluster"/'${cluster_name}'/' ${galerafile}
    sed -i 's/wsrep_on=0/wsrep_on=ON/' ${galerafile}
    sed -i 's/#wsrep_provider_options=/wsrep_provider_options="gcache.size=2G;gcs.fc_limit=128"/' ${galerafile}

    echo "Put Mariadb nodes IP Adress like:- IP1,IP2,IP3."
    read nodes
    read -p "Put Mariadb Node IP Adress: " node_address
    read -p "Put Mariadb Node IP HostName: " wsrep_node_name
    
    if [ "$wsrep_cluster_address" != '' ]; then
        echo "wsrep_cluster_address="gcomm://${nodes},${wsrep_cluster_address}"" | tee -a ${galerafile}
        echo "wsrep_node_name="${wsrep_node_name}"" | tee -a ${galerafile}
        echo "wsrep_node_address="${node_address}"" | tee -a ${galerafile}
    else 
        echo Please provide required input
        exit 
    fi

}

function mariadb_config(){

cp -f /etc/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf-bkp
cat >/etc/my.cnf.d/mariadb-server.cnf <<EOF
[server]

# this is only for the mysqld standalone daemon
# Settings user and group are ignored when systemd is used.
# If you need to run mysqld under a different user or group,
# customize your systemd unit file for mysqld/mariadb according to the
# instructions in http://fedoraproject.org/wiki/Systemd

[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mariadb/mariadb.log
pid-file=/run/mariadb/mariadb.pid

# Skip reverse DNS lookup of clients
skip-name-resolve

# InnoDB
innodb_buffer_pool_size         = 40G
innodb_buffer_pool_instances    = 15
innodb_lock_wait_timeout        = 500
innodb_flush_log_at_trx_commit  = 2
innodb_file_per_table           = 1
innodb_stats_on_metadata        = 0
innodb_page_cleaners            = 8

innodb_read_io_threads          = 300
innodb_write_io_threads         = 300
innodb_log_buffer_size          = 4M
innodb_log_file_size            = 8G
#innodb_flush_method             = O_DIRECT
#innodb_autoinc_lock_mode        = 2

innodb_adaptive_hash_index      = 0

# Connection Settings
max_connections                 = 30000
interactive_timeout             = 5000
wait_timeout                    = 5000
thread_cache_size               = 6
thread_stack                    = 192K

#TableSettings
tmp_table_size                  = 1G
max_heap_table_size             = 1G
table_open_cache                = 500
table_definition_cache          = 1
max_allowed_packet              = 500M
performance_schema              = OFF

[embedded]

# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]

# This group is only read by MariaDB-10.5 servers.
# If you use the same .cnf file for MariaDB of different versions,
# use this group for options that older servers don't understand
[mariadb-10.5]

EOF

}


function master(){

    comm=$(mysql -u root -p$MARIADB_ROOT_PASSWORD -e "SHOW GLOBAL STATUS LIKE 'wsrep_cluster_size';" | grep wsrep_cluster_size | awk '{print $2}')

    if [[ -n "${comm}" ]]; then

        echo -e "${G}Maiadb cluster already running${C} ${wsrep_cluster_address}, Total cluster nodes count is: ${R}${comm}${C}"
        break
    else
        #Galera cluster setup

        mariadb_server_galera
        galera_config_master
        mariadb_config

        sudo galera_new_cluster
        sudo systemctl enable 'mariadb.service' &>/dev/null
        sudo sudo systemctl start 'mariadb.service' &>/dev/null
        mysql_secure_installation

        if [ $? -eq 0 ]; then

            echo -e "${G}Mariadb Galera cluster successfully started!${C}"
        else
            echo -e "${R}Failed ${Y}Check error logs and configuration then run script again!${C}"
            exit
        fi
    fi
}

function nodes(){

    echo 'Nodes setup inprogress...'

    mariadb_server_galera
    galera_config_node
    mariadb_config

    if [ -d "/var/lib/mysql" ]; then
        echo "directory \"/var/lib/mysql\" exists"
        sudo systemctl stop 'mariadb.service' &>/dev/null
        rm -rf /var/lib/mysql/*
    fi

    sudo sudo systemctl enable 'mariadb.service' &>/dev/null
    sudo systemctl start 'mariadb.service' &>/dev/null

    if [ $? -eq 0 ]; then

       echo "Node successfully added"

    else

       echo "Failed to add node!"

    fi

}

if [[ -n "${@}" ]]; then
        echo 'Galera Mariadb cluster installation...'
        $@
else 
    echo "Run below command for install Mariadb cluster"
    echo  ${0##*/} master
    echo ${0##*/} nodes
fi



