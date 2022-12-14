#!/bin/bash
set -o pipefail

is_wsl() {
	case "$(uname -r)" in
	*microsoft* ) true ;; # WSL 2
	*Microsoft* ) true ;; # WSL 1
	* ) false;;
	esac
}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "$lsb_dist"
}

is_dry_run() {
	if [ -z "$DRY_RUN" ]; then
		return 1
	else
		return 0
	fi
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

echo_run_as_nonroot() {
	
	run='/usr/local/bin/run'
	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	 case "$lsb_dist" in

		ubuntu|debian|raspbian)
			if is_wsl; then
				echo "WSL DETECTED: We recommend using apache2 for Windows."	
				$sh_c "echo '#!/bin/sh' > $run"
				$sh_c "echo 'sudo service apache2 start' >> $run"
				$sh_c "echo 'sudo service mariadb start' >> $run"
				$sh_c "echo 'sudo service rabbitmq-server start' >> $run"
				$sh_c "echo 'sudo service mongodb start' >> $run"
			else 
				service="systemctl enable --now"
				$sh_c "sudo $service apache2"
				$sh_c "sudo $service mariadb"
				$sh_c "sudo $service rabbitmq-server"
				$sh_c "sudo $service mongodb"
			fi
		;;
		centos|rhel|sles)	
			if is_wsl; then
				echo "WSL DETECTED: We recommend using httpd for Windows."

				cat <<-EOF > /usr/local/bin/run
				#!/bin/bash
				ssh-keygen -A
				cd /etc/ssh/
				/usr/sbin/sshd
				cd /etc/httpd/
				install -d /run/httpd/
				/usr/sbin/httpd
				cd /var/www/html/
				EOF

				if [ ! -e "/mnt/c/html" ]; then

					$sh_c "install -d /mnt/c/html"
				fi
				if [ ! -h "/var/www/html" ]; then
					$sh_c "cd /var/www/"
					$sh_c "rm -rf html"
					$sh_c "ln -s /mnt/c/html html"
				fi

				if [ "$lsb_dist" != "ubuntu" ]; then
					SSL=$(curl -SL https://github.com/govindinfi/ssl/blob/main/ssl2.sh?raw=true 2>/dev/null| bash)
				fi
				
				$sh_c "run"

			else

				service="systemctl enable --now"
				sudo $service httpd.service
				sudo $service mariadb.service
				sudo $service mongod.service
				sudo $service rabbitmq-server.service
				rabbitmq-adduser
				firewall
				$sh_c "mongo --eval 'db.runCommand({ connectionStatus: 1 })'"
			fi
		;;
	esac
	$sh_c "chmod +x /usr/local/bin/run"

	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	if [ "$lsb_dist" != "ubuntu" ]; then
		SSL=$(curl -SL https://github.com/govindinfi/ssl/blob/main/ssl2.sh?raw=true 2>/dev/null| bash)
	fi

	echo "Installation has been successfully Done"
	echo "clone code into C:\html\ directory"

}


# Check if this is a forked Linux distro
check_forked() {

	# Check for lsb_release command existence, it usually exists in forked distros
	if command_exists lsb_release; then
		# Check if the `-u` option is supported
		set +e
		lsb_release -a -u > /dev/null 2>&1
		lsb_release_exit_code=$?
		set -e

		# Check if the command has exited successfully, it means we're in a forked distro
		if [ "$lsb_release_exit_code" = "0" ]; then
			# Print info about current distro
			cat <<-EOF
			You're using '$lsb_dist' version '$dist_version'.
			EOF

			# Get the upstream release info
			lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
			dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')

			# Print info about upstream distro
			cat <<-EOF
			Upstream release is '$lsb_dist' version '$dist_version'.
			EOF
		else
			if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
				if [ "$lsb_dist" = "osmc" ]; then
					# OSMC runs Raspbian
					lsb_dist=raspbian
				else
					# We're Debian and don't even know it!
					lsb_dist=debian
				fi
				dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
				case "$dist_version" in
					11)
						dist_version="bullseye"
					;;
					10)
						dist_version="buster"
					;;
					9)
						dist_version="stretch"
					;;
					8)
						dist_version="jessie"
					;;
				esac
			fi
		fi
	fi
}

firewall() {
	firewall-cmd --add-port=15672/tcp --permanent >/dev/null
	firewall-cmd --add-port=5672/tcp --permanent >/dev/null
	firewall-cmd --add-port=4369/tcp --permanent >/dev/null
	firewall-cmd --add-service=http --permanent >/dev/null
	firewall-cmd --add-service=https --permanent >/dev/null
	firewall-cmd --add-service=mysql --permanent >/dev/null
	firewall-cmd --add-service=mongodb --permanent >/dev/null
	firewall-cmd --add-service=ftp --permanent >/dev/null
	firewall-cmd --reload 
}

mongodb() {
	echo "Installing Mongodb Server...."

	cat <<-EOF > /etc/yum.repos.d/mongodb-org.repo
		[mongodb-org]
		name=MongoDB Repository
		baseurl=https://repo.mongodb.org/yum/redhat/8Server/mongodb-org/5.0/x86_64/
		gpgcheck=1
		enabled=1
		gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc	
		EOF
                        
	$sh_c "$pkg_manager install mongodb-org -y >/dev/null"

	$sh_c cat <<-EOF > /etc/systemd/system/disable-thp.service 
		[Unit]
		Description=Disable Transparent Huge Pages (THP)
		After=sysinit.target local-fs.target
		Before=mongod.service

		[Service]
		Type=oneshot
		ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'

		[Install]
		WantedBy=basic.target
		EOF

	$sh_c "systemctl daemon-reload"
	$sh_c "systemctl start disable-thp.service"
	$sh_c "cat /sys/kernel/mm/transparent_hugepage/enabled"

	$sh_c "install -d /etc/tuned/no-thp/"
	$sh_c cat <<-EOF > /etc/tuned/no-thp/tuned.conf
	[main]
	include=virtual-guest

	[vm]
	transparent_hugepages=never
	EOF
				
	$sh_c "tuned-adm profile no-thp"
}

webserver() {
	echo "Installing WebServer..."
	$sh_c "$pkg_manager clean all"
	$sh_c "$pkg_manager makecache >/dev/null"
	$sh_c "$pkg_manager install -y  $pre_reqs $pkg_epel >/dev/null"
	$sh_c "$pkg_manager -y  install httpd mod_ssl mod_http2 >/dev/null"
	$sh_c "$pkg_manager install -y  $remi_repo >/dev/null"
	$sh_c "$pkg_manager -y  module install php:remi-7.4 >/dev/null"
	$sh_c "$pkg_manager -y  install php php-{cli,common,devel,fedora-autoloader.noarch,gd,gmp,json,ldap,mbstring,mcrypt,mysqlnd,opcache,pdo,pear.noarch,pecl-amqp,pecl-ssh2,pecl-zip,process,snmp,xml,pecl-mongodb,pecl-amqp} >/dev/null"
	$sh_c "sed -i '/mpm_prefork_module/ s/^#//' /etc/httpd/conf.modules.d/00-mpm.conf && sed -i '/mpm_event_module/ s/^/#/g' /etc/httpd/conf.modules.d/00-mpm.conf >/dev/null" 
	$sh_c "$pkg_manager autoremove -y >/dev/null"
	$sh_c "rm -f /var/lib/rpm/__db.*"
	$sh_c "db_verify /var/lib/rpm/Packages >/dev/null"
	$sh_c "rpm --rebuilddb >/dev/null"
	$sh_c "$pkg_manager -y install nmap git composer mariadb net-snmp net-snmp-utils >/dev/null"
	$sh_c 'pear channel-update pear.php.net >/dev/null'
	$sh_c 'pear install -f Net_Nmap >/dev/null'
	if [[ -z $(grep "ixed.7.4.lin" /etc/php.ini) ]]; then
		$sh_c 'curl -s "http://www.sourceguardian.com/loaders/download.php?php_v=7.4.30&php_ts=0&php_is=8&os_s=Linux&os_r=4.18.0-408.el8.x86_64&os_m=x86_64" -o /usr/lib64/php/modules/ixed.7.4.lin'
		$sh_c "echo 'extension=ixed.7.4.lin' >> /etc/php.ini"
	fi
}

mariadb() {
	echo "Installing Mongodb Server...."
	cat <<-EOF > /etc/yum.repos.d/Mariadb.repo
	# MariaDB 10.8 CentOS repository list - created 2022-08-02 09:12 UTC
	# https://mariadb.org/download/
	[mariadb]
	name = MariaDB
	baseurl = https://mariadb.mirror.digitalpacific.com.au/yum/10.8/centos8-amd64
	module_hotfixes=1
	gpgkey=https://mariadb.mirror.digitalpacific.com.au/yum/RPM-GPG-KEY-MariaDB
	gpgcheck=1
	EOF

	$sh_c "$pkg_manager -y install MariaDB-server MariaDB-client >/dev/null"
}

rabbitmq-server() {
	echo "Installing RabbitMQ...."

	curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.rpm.sh' | sudo -E bash >/dev/null
	curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | sudo bash >/dev/null
	$sh_c "$pkg_manager install socat logrotate -y >/dev/null"
	$sh_c "$pkg_manager -y install rabbitmq-server erlang >/dev/null"
	rabbitmq-plugins enable rabbitmq_management
}

rabbitmq-adduser() {
	rabbitmqctl add_user admin Infi@123# >/dev/null
	rabbitmqctl set_user_tags admin administrator >/dev/null
	rabbitmqctl set_permissions -p / admin ".*" ".*" ".*" >/dev/null
}

do_install() {
	echo "# Executing infiworx install script."

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
			cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit 1
		fi
	fi

	# perform some very rudimentary platform detection
	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	case "$lsb_dist" in

		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
		;;

		debian|raspbian)
			dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
			case "$dist_version" in
				11)
					dist_version="bullseye"
				;;
				10)
					dist_version="buster"
				;;
				9)
					dist_version="stretch"
				;;
				8)
					dist_version="jessie"
				;;
			esac
		;;

		centos|rhel|sles)
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --release | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

	esac

	# Check if this is a forked Linux distro
	check_forked

	# Print deprecation warnings for distro versions that recently reached EOL,
	# but may still be commonly used (especially LTS versions).
	case "$lsb_dist.$dist_version" in
		debian.stretch|debian.jessie)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		raspbian.stretch|raspbian.jessie)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		ubuntu.xenial|ubuntu.trusty)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		fedora.*)
			if [ "$dist_version" -lt 33 ]; then
				deprecation_notice "$lsb_dist" "$dist_version"
			fi
			;;
	esac

	# Run setup for each distro accordingly
	case "$lsb_dist" in
		ubuntu|debian|raspbian)
			pre_reqs="apt-transport-https ca-certificates curl libzip-dev librabbitmq-dev libmcrypt-dev"
			if ! command -v gpg > /dev/null; then
				pre_reqs="$pre_reqs gnupg"
			fi
			(
				$sh_c 'apt-get update -y'
				$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y  $pre_reqs"
				$sh_c "apt-get install apache2 nmap -y"
				$sh_c "apt-get install php php7.4-common php7.4-mysql php7.4-opcache php-cli php-pear php-dev php-gd php-gmp php-json php-ldap php-mbstring php-pear php-ssh2 php-snmp php-xml php-zip php-mongodb php-amqp -y"
				$sh_c "pecl channel-update pear.php.net"
				
				if [[ -z $(php -m | grep mcrypt) ]]; then
					$sh_c "printf "\n" | pecl install -f mcrypt"
					$sh_c "echo "extension=mcrypt.so" >> /etc/php/7.4/apache2/php.ini"
					$sh_c "echo "extension=mcrypt.so" >> /etc/php/7.4/cli/php.ini"
				fi

				$sh_c "pear install -f Net_Nmap"
				$sh_c "apt-get install rabbitmq-server erlang mongodb -y"
				$sh_c "apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'"
				$sh_c "add-apt-repository 'deb [arch=amd64] http://mariadb.mirror.globo.tech/repo/10.9/ubuntu focal main'"
				$sh_c "apt update -y"
				$sh_c "apt-get install mariadb-server mariadb-client -y"
				$sh_c 'apt-get update -y'
				$sh_c "apt-get clean"
            )
			echo_run_as_nonroot
			exit 0
			;;
		centos|fedora|rhel)
		
			remi_repo="https://rpms.remirepo.net/enterprise/remi-release-8.rpm"
			epel_repo="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
			if ! curl -Ifs "$remi_repo" > /dev/null; then
				echo "Error: Unable to curl repository file $remi_repo, is it valid?"
				exit 1
			fi
			if [ "$lsb_dist" = "fedora" ]; then 
				pkg_manager="dnf"
				config_manager="dnf config-manager"
				enable_channel_flag="--set-enabled"
				disable_channel_flag="--set-disabled"
				pre_reqs="dnf-plugins-core"
				pkg_suffix="fc$dist_version"
				pkg_epel="epel-release"
			elif [ "$lsb_dist" = "centos" ] || [ "$dist_version" = '8' ]; then
				pkg_manager="dnf"
				config_manager="dnf config-manager"
				enable_channel_flag="--set-enabled"
				disable_channel_flag="--set-disabled"
				pre_reqs="dnf-plugins-core"
				pkg_suffix="el"
				pkg_epel="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
			fi
			(
				if ! is_dry_run; then
					set -x
				fi
				if is_wsl; then
					echo "WSL DETECTED: Installing HTTPD for Windows."
					webserver
				else
					webserver
					mongodb
					mariadb
					rabbitmq-server
					$sh_c "$pkg_manager clean all"
				fi
			)
			echo_run_as_nonroot
			exit 0
			;;
			
		*)
			if [ -z "$lsb_dist" ]; then
				if is_darwin; then
					echo
					echo "ERROR: Unsupported operating system 'macOS'"
					echo
					exit 1
				fi
			fi
			echo
			echo "ERROR: Unsupported distribution '$lsb_dist'"
			echo
			exit 1
			;;
	esac
	exit 1
}

# half the file during "curl | sh"
do_install


