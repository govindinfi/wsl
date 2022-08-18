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
				echo "#!/bin/sh" > $run
				echo "sudo service apache2 start" >> $run
				echo "sudo service mariadb start" >> $run
				echo "sudo service rabbitmq-server start" >> $run
				echo "sudo service mongodb start" >> $run
			else 
				service="systemctl enable --now"
				sudo $service apache2
				sudo $service mariadb
				sudo $service rabbitmq-server
				sudo $service mongodb
			fi
		;;
		centos|rhel|sles)	
			if is_wsl; then
				echo "WSL DETECTED: We recommend using httpd for Windows."
				echo "#!/bin/bash" > $run
				echo "" >> $run
				echo "ssh-keygen -A" >> $run
				echo "cd /etc/ssh/" >> $run
				echo "/usr/sbin/sshd" >> $run

				cd /etc/httpd/
				install -d /run/httpd/
				/usr/sbin/httpd
			else
				service="systemctl enable --now"
				sudo $service apache2
				sudo $service mariadb
				sudo $service rabbitmq-server
				sudo $service mongodb
			 fi
		;;
	esac
	chmod +x /usr/local/bin/run
	SSL=$(curl -SL https://github.com/govindinfi/ssl/blob/main/ssl2.sh?raw=true 2>/dev/null| bash)
	$sh_c "run"
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
				$sh_c "apt-get install php php-{cli,pear,dev,common,gd,gmp,json,ldap,mbstring,mysqlnd,opcache,pdo,pear,ssh2,snmp,xml,zip,mongodb,amqp} -y"
				$sh_c "pecl channel-update pear.php.net"
				$sh_c "pear install Net_Nmap"
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
				if is_wsl; then
					echo "WSL DETECTED: Installing HTTPD for Windows."
					
					$sh_c "$pkg_manager clean all"
					$sh_c "$pkg_manager install -y  $pre_reqs $pkg_epel"
					$sh_c "$pkg_manager makecache"
					$sh_c "$pkg_manager -y  install httpd mod_ssl mod_http2"
					$sh_c "$pkg_manager install -y  $remi_repo"
					$sh_c "$pkg_manager -y  module install php:remi-7.4"
					$sh_c "$pkg_manager -y  install php php-{cli,common,devel,fedora-autoloader.noarch,gd,gmp,json,ldap,mbstring,mcrypt,mysqlnd,opcache,pdo,pear.noarch,pecl-amqp,pecl-ssh2,pecl-zip,process,snmp,xml,pecl-mongodb,pecl-amqp}"
					$sh_c "sed -i '/mpm_prefork_module/ s/^#//' /etc/httpd/conf.modules.d/00-mpm.conf && sed -i '/mpm_event_module/ s/^/#/g' /etc/httpd/conf.modules.d/00-mpm.conf" 
					$sh_c "$pkg_manager autoremove -y"
					$sh_c "$pkg_manager -y install nmap git composer mariadb"
					$sh_c 'pear channel-update pear.php.net'
					$sh_c 'pear install Net_Nmap'
					if [[ -z $(grep "ixed.7.4.lin" /etc/php.ini) ]]; then
						$sh_c 'curl -s "http://www.sourceguardian.com/loaders/download.php?php_v=7.4.30&php_ts=0&php_is=8&os_s=Linux&os_r=4.18.0-408.el8.x86_64&os_m=x86_64" -o /usr/lib64/php/modules/ixed.7.4.lin'
						$sh_c "echo 'extension=ixed.7.4.lin' >> /etc/php.ini"
					fi
					$sh_c "$pkg_manager clean all"
				else
					$sh_c "$pkg_manager clean all"
					$sh_c "$pkg_manager install -y  $pre_reqs $pkg_epel"
					$sh_c "$pkg_manager makecache"
					$sh_c "$pkg_manager -y  install httpd mod_ssl mod_http2"
					$sh_c "$pkg_manager install -y  $remi_repo"
					$sh_c "$pkg_manager -y  module install php:remi-7.4"
					$sh_c "$pkg_manager -y  install php php-{cli,common,devel,fedora-autoloader.noarch,gd,gmp,json,ldap,mbstring,mcrypt,mysqlnd,opcache,pdo,pear.noarch,pecl-amqp,pecl-ssh2,pecl-zip,process,snmp,xml,pecl-mongodb,pecl-amqp}"
					$sh_c "sed -i '/mpm_prefork_module/ s/^#//' /etc/httpd/conf.modules.d/00-mpm.conf && sed -i '/mpm_event_module/ s/^/#/g' /etc/httpd/conf.modules.d/00-mpm.conf" 
					$sh_c "$pkg_manager autoremove -y"
					$sh_c "$pkg_manager -y install nmap git composer mariadb"
					$sh_c "pear channel-update pear.php.net"
					$sh_c "pear install Net_Nmap"
					if [[ -z $(grep "ixed.7.4.lin" /etc/php.ini) ]]; then	
						$sh_c 'curl -s "http://www.sourceguardian.com/loaders/download.php?php_v=7.4.30&php_ts=0&php_is=8&os_s=Linux&os_r=4.18.0-408.el8.x86_64&os_m=x86_64" -o /usr/lib64/php/modules/ixed.7.4.lin'
						$sh_c 'echo "extension=ixed.7.4.lin" | tee -a /etc/php.ini'
					fi
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


