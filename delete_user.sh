#!/bin/bash

if [ $(id -u) -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./delete_user.sh'\n"
	exit 1
fi

script=$(readlink -f "$0")
local_path=$(dirname "$script")

## Clear spaces, tabs, empty lines & comments in config file
sed "s/ *= */=/g; s/	//g; s/[#].*$//; /^$/d;" "$local_path/config.ini" > "$local_path/tmp/local_config.ini"

# Check config file exist
if [ ! -f "$local_path/tmp/local_config.ini" ]; then
	echo "Config file not found!"
	exit
fi

source "$local_path/tmp/local_config.ini"

echo
echo "============================== Data =========================================="
echo

if [ "$debug" == "Y" -o "$debug" == "y" ]; then
	DOMAIN_NAME="$debug_domain"
else
	read -e -p "Please enter domain name (*): " DOMAIN_NAME
	if [ -z "$DOMAIN_NAME" ]; then
		echo
		echo "$(tput setaf 1) Error: Domain name is empty $(tput sgr 0)"
		exit 0
	fi
fi

if [ "$debug" == "Y" -o "$debug" == "y" ]; then
	USER_NAME="$debug_user"
else
	echo

	read -e -p "Please enter user name (*): " USER_NAME
	if [ -z "$USER_NAME" ]; then
		echo
		echo "$(tput setaf 1) Error: User name is empty $(tput sgr 0)"
		exit 0
	fi
fi

echo
echo "============================== Checking ======================================"
echo

echo "<- Check username exists"

# Check user exist?
id $USER_NAME &> /dev/null

if [ $? -eq 1 ]; then
	echo "-> $(tput setaf 1)$USER_NAME do not exists.$(tput sgr 0)"
	exit
fi
echo "-> $(tput setaf 2)Ok$(tput sgr 0)"

pkill -u "$USER_NAME"
userdel -rf "$USER_NAME"
crontab -r -u "$USER_NAME"

rm -rf "/etc/nginx/access/$DOMAIN_NAME"
rm -rf "/etc/nginx/ssl/$DOMAIN_NAME"
rm -rf "$web_server_dir/$DOMAIN_NAME"
rm "$nginx_config_location/$DOMAIN_NAME.conf"
rm -rf "$certificate_location/$DOMAIN_NAME"

rm "$php_fpm_pool_location/$DOMAIN_NAME.conf"
rm -rf "/var/lib/php/session/$DOMAIN_NAME"
rm -rf "/var/lib/php/wsdlcache/$DOMAIN_NAME"

if [ -f "$logrotate_site_config_dir/$DOMAIN_NAME" ]; then
	rm -rf "$logrotate_site_config_dir/$DOMAIN_NAME"
fi

#Python Service
SERVICE_NAME="${DOMAIN_NAME%.*}"

if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
	rm "/etc/systemd/system/$SERVICE_NAME.service"
fi

echo
read -e -p "Restart Nginx & PHP-FPM? (Y/n) (default n): " RESTART_SERVICES

if [ "$RESTART_SERVICES" == "Y" -o "$RESTART_SERVICES" == "y" ]; then
	echo "<- Restart Services"
	/bin/systemctl restart nginx.service
	/bin/systemctl restart php-fpm.service
	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
fi

echo
echo "============================== Summary ======================================="
echo " $(tput setaf 2)"

echo "-> Domain: $DOMAIN_NAME"
echo "-> User: $USER_NAME"
echo " $(tput sgr 0)"

echo

exit 0