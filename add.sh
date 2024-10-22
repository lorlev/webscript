#!/bin/bash

if [ $(id -u) -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./add.sh'\n"
	exit 1
fi

script=$(readlink -f "$0")
local_path=$(dirname "$script")

if [ ! -d "$local_path/tmp" ]; then
	mkdir "$local_path/tmp"
fi

# Check config file exist
if [ ! -f "$local_path/config.ini" ]; then
	cp "$local_path/config.example.ini" "$local_path/config.ini"
	echo "$(tput setaf 1) Config file was moved from the example file! $(tput sgr 0)"
	echo "$(tput setaf 1) Don't forget to configure the config file! $(tput sgr 0)"
fi

## Clear spaces, tabs, empty lines & comments in config file
sed "s/ *= */=/g; s/	//g; s/[#].*$//; /^$/d;" "$local_path/config.ini" > "$local_path/tmp/local_config.ini"

# Check tmp config file exist
if [ ! -f "$local_path/tmp/local_config.ini" ]; then
	echo "Config file not found!"
	exit
fi

source "$local_path/tmp/local_config.ini"
source "$local_path/inc/functions.sh"

SelfUpdate

trap Finish 2

echo
echo "============================== Data =========================================="
echo

echo "Choose Technology:"
echo "(1) Nginx + PHP-FPM"
echo "(2) Nginx + Python + Gunicorn"
echo "(3) Nginx + PHP-FPM + React"

read -e -p "(Q) Quit? " CHOOSE_TECHNOLOGY
case "$CHOOSE_TECHNOLOGY" in
	"1") TECHNOLOGY="php";;
	"2") TECHNOLOGY="python";;
	"3") TECHNOLOGY="react";;
	"q"|"Q") Finish;;
esac
echo

#Inclide Choosed Technology
source "$local_path/inc/install_$TECHNOLOGY.sh"

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

echo

read -e -p "Is SubDomain? (Y/n) (default n): " IS_SUBDOMAIN
if [ -z "$IS_SUBDOMAIN" ]; then
	IS_SUBDOMAIN='n'
fi
echo

read -e -p "Is SSL? (Y/n) (default n): " IS_SSL
if [ -z "$IS_SSL" ]; then
	IS_SSL='n'
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

# Check user exist?
id $USER_NAME &> /dev/null

if [ $? -eq 0 ]; then
	echo
	echo "$(tput setaf 1) $USER_NAME already exists. $(tput sgr 0)"
	exit 0
fi

echo

if [ "$auto_password_gen" == "Y" -o "$auto_password_gen" == "y" ]; then
	USER_PASSWORD=$(openssl rand -base64 $auto_password_gen_length)
	echo "Password Generated Successfully (Password Length: $auto_password_gen_length)"
else
	read -s -p "Please enter user password (*): " USER_PASSWORD

	echo
	echo

	read -s -p "Please repeat user password (*): " USER_PASSWORD2

	# Check both passwords match
	if [ $USER_PASSWORD != $USER_PASSWORD2 ]; then
		echo
		echo "$(tput setaf 1) Passwords do not match $(tput sgr 0)"
		exit
	fi

	echo
fi

echo

read -e -p "Has Auto Deploy? (Y/n) (default y): " AUTO_DEPLOY
if [ -z "$AUTO_DEPLOY" ]; then
	AUTO_DEPLOY='y'
fi

echo

HAS_GIT='n'
GIT_BRANCH='production'

if [ -n "$git_branch" ]; then
	GIT_BRANCH=$git_branch
else
	if [ $HOSTNAME = "test.server" ]; then
		GIT_BRANCH='test'
	fi
fi

if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
	#Notification
	if [ "$push_notification" == "Y" -o "$push_notification" == "y" ]; then
		read -e -p "Has Push Notifications? (Y/n) (default n): " PUSH
		if [ -z "$PUSH" ]; then
			PUSH='n'
		fi
		echo
	else
		PUSH='n'
	fi

	#Git
	if [ "$debug" == "Y" -o "$debug" == "y" ]; then
		HAS_GIT="$debug_has_git"
		GIT_REPO_URL="$debug_git_repo"
	else
		read -e -p "Has Git? (Y/n) (default n): " HAS_GIT
		if [ "$HAS_GIT" == "Y" -o "$HAS_GIT" == "y" ]; then
			echo
			read -e -p "Please enter Git Repository SSH URL (*): " GIT_REPO_URL
			echo
		fi
	fi
fi

AskServiceRequirements

echo
echo "============================== Process ======================================"
echo

if [ ! -d "$web_server_dir" ]; then
	echo "<- Create Web directory"

	mkdir "$web_server_dir"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	echo
fi

CreateUser

PrepeareUserDirs

CreateLogs
CreateDirs
CreateConfig

if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
	SyncToBitbucketIPRange
fi

echo
echo "<- Create Nginx Config file"

source "$local_path/config.templates/nginx/nginx.base.sh"

echo -e "${NGINX_BASE_CONFIG}" > "$nginx_config_location/$DOMAIN_NAME.conf"

echo "-> $(tput setaf 2)Ok$(tput sgr 0)"

NginxAccessStructure

if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
	CreateAutoDeploy
fi

if [ "$HAS_GIT" == "N" -o "$HAS_GIT" == "n" ]; then
	CreateUnderConstructionPage
fi

CreateErrorPages

if [ "$HAS_GIT" == "Y" -o "$HAS_GIT" == "y" ]; then
	echo
	echo "<- Clone Git Repository"

	echo
	echo "Access Key is:$(tput setaf 2) $(cat $web_server_dir/$DOMAIN_NAME/auto.deploy/access/access-key.pub)$(tput sgr 0)"
	echo

	read -e -p "Begin Repository Clone? (Y/n) (default n): " REPOSITORY_CLONE

	if [ "$REPOSITORY_CLONE" == "Y" -o "$REPOSITORY_CLONE" == "y" ]; then
		umask 002

		echo
		read -e -p "Checkout $GIT_BRANCH Branch? (Y/n) (default y): " CHECKOUT_BRANCH
		if [ -z "$CHECKOUT_BRANCH" ]; then
			CHECKOUT_BRANCH='y'
		fi

		echo
		echo "<- Start Cloning Repository"

		ERROR_FILE=$(mktemp)

		if ssh-agent sh -c "ssh-add $web_server_dir/$DOMAIN_NAME/auto.deploy/access/access-key > /dev/null 2>>$ERROR_FILE; git clone $GIT_REPO_URL $web_server_dir/$DOMAIN_NAME/htdocs > /dev/null 2>>$ERROR_FILE"; then
			cd "$web_server_dir/$DOMAIN_NAME/htdocs"

			git config core.filemode false

			if [ "$CHECKOUT_BRANCH" == "Y" -o "$CHECKOUT_BRANCH" == "y" ]; then
				echo "<- Switched to a new branch: $GIT_BRANCH"

				if git checkout -b $GIT_BRANCH "origin/$GIT_BRANCH" > /dev/null 2>&1; then
					echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
				else
					echo "-> $(tput setaf 1)Fail$(tput sgr 0)"
				fi
			fi

			ExecuteScript

			umask 0022
			echo "-> Clone Git Repository $(tput setaf 2)Ok$(tput sgr 0)"
			echo
		else
			echo
			echo "-> Clone Git Repository $(tput setaf 1)Fail$(tput sgr 0)"
			echo "Reason for failure: $(tput setaf 1)"
			cat $ERROR_FILE
			echo "$(tput sgr 0)"
			echo
		fi

		rm -f $ERROR_FILE
	fi
fi

chown -R $USER_NAME:$global_group "$web_server_dir/$DOMAIN_NAME/htdocs"

if [ "$IS_SSL" == "Y" -o "$IS_SSL" == "y" ]; then
	if [ ! -d "$certificate_location" ]; then
		mkdir -p "$certificate_location"
	fi

	mkdir -p "$certificate_location/$DOMAIN_NAME"
	chmod -R 600 "$certificate_location/$DOMAIN_NAME"

	if [ "$self_signed_certificate" == "Y" -o "$self_signed_certificate" == "y" ]; then
		GenerateSelfSignedSSL
	fi

	if [ "$certificate_signing_request" == "Y" -o "$certificate_signing_request" == "y" ]; then
		GenerateCSR
	fi
fi

if [ "$bash_logger" == "Y" -o "$bash_logger" == "y" ]; then
	AddBashLogger
fi

if [ "$logrotate_enabled" == "Y" -o "$logrotate_enabled" == "y" ]; then
	CreateLogRotate
fi

echo
read -e -p "Restart Services? (Y/n) (default n): " RESTART_SERVICES

if [ "$RESTART_SERVICES" == "Y" -o "$RESTART_SERVICES" == "y" ]; then
	echo "<- Restart Services"
	/bin/systemctl restart nginx.service

	RestartService

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
fi

echo
echo "============================== Summary ======================================="
echo " $(tput setaf 2)"

echo "-> Domain: $DOMAIN_NAME"
echo "-> User: $USER_NAME"
echo "-> Password: $USER_PASSWORD"
echo "-> Working directory is: $web_server_dir/$DOMAIN_NAME/htdocs"

GetServiceSummary

if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
	echo "-> Auto Deploy URL is: $DOMAIN_NAME/auto.deploy"
	echo "-> Access Key is: $(cat $web_server_dir/$DOMAIN_NAME/auto.deploy/access/access-key.pub)"
fi

echo " $(tput sgr 0)"
echo

exit 0