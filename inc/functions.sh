#!/bin/sh

SelfUpdate(){
	echo
	echo 'Checking for a New Version (Update Check)'
	cd "$local_path" || { echo "Failed to change directory to $local_path"; exit 1; }

	git remote update > /dev/null 2>&1

	UPSTREAM=${1:-'@{u}'}
	LOCAL=$(git rev-parse '@{0}')
	REMOTE=$(git rev-parse "$UPSTREAM")
	BASE=$(git merge-base '@{0}' "$UPSTREAM")

	if [ "$LOCAL" = "$REMOTE" ]; then
		echo "Up-to-date"
	elif [ "$LOCAL" = "$BASE" ]; then
		echo "New version available. Attempting to update..."
		git pull
		echo "Update completed. Restarting required."
		exit 0
	elif [ "$REMOTE" = "$BASE" ]; then
		echo "Local version has uncommitted changes!"
	else
		echo "Branches have diverged. Manual intervention needed."
	fi
}

CreateUser(){
	echo "<- Add user: $USER_NAME"
	useradd -m -g $global_group -s /usr/sbin/nologin -d "$web_server_dir/$DOMAIN_NAME" "$USER_NAME"

	# Does User exist?
	id $USER_NAME &> /dev/null

	if [ $? -ne 0 ]; then
		echo "-> $(tput setaf 1)Failed to create an account $USER_NAME$(tput sgr 0)";
		exit
	fi

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	echo

	echo "<- Add user password"
	echo -e "$USER_PASSWORD\n$USER_PASSWORD" | (passwd --stdin $USER_NAME) &> /dev/null
	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	echo
}

PrepeareUserDirs(){
	chown root:$global_group "$web_server_dir/$DOMAIN_NAME"
	chmod 755 "$web_server_dir/$DOMAIN_NAME"

	rm "$web_server_dir/$DOMAIN_NAME/.bash_logout" -f
	rm "$web_server_dir/$DOMAIN_NAME/.bash_profile" -f
	rm "$web_server_dir/$DOMAIN_NAME/.bashrc" -f
	rm "$web_server_dir/$DOMAIN_NAME/.cloud-locale-test.skip" -f

	echo "<- Directory create";
	mkdir "$web_server_dir/$DOMAIN_NAME/htdocs"
	mkdir "$web_server_dir/$DOMAIN_NAME/server.logs"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"

	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/nginx.access.log"
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/nginx.error.log"

	chmod 775 "$web_server_dir/$DOMAIN_NAME/htdocs"
	chmod -R 775 "$web_server_dir/$DOMAIN_NAME/server.logs"
}

CreateLogRotate(){
	echo
	echo "<- Create Log Rotate";

	if [ ! -d $logrotate_site_config_dir ]; then
		echo "-- Create Web directory";
		mkdir $logrotate_site_config_dir
	fi

	#Check included or not web directory
	if ! grep -q -w "include $logrotate_site_config_dir" $logrotate_config_file; then
		echo "-- Update main config file";
		echo -e "\n#web sites log files\ninclude $logrotate_site_config_dir" >> $logrotate_config_file
	fi

	sed "s/{domain}/$DOMAIN_NAME/g; s/{file_size}/$logrotate_file_size/g; s|{web_server_dir}|$web_server_dir|g; s|{group}|$global_group|g" "$local_path/config.templates/logrotate.default" > "$logrotate_site_config_dir/$DOMAIN_NAME"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

CreateAutoDeploy(){
	echo
	echo "<- Create Auto Deploy";

	if git clone https://github.com/lorlev/ad2.git "$web_server_dir/$DOMAIN_NAME/auto.deploy" > /dev/null 2>&1; then
		cp "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env.example" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
		## Clear spaces, tabs, empty lines & comments in config file
		export $(sed "s/ *= */=/g; s/	//g; s/[#].*$//; /^$/d;" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env")

		sed -i "s/PUSH[[:space:]]*=.*/PUSH\t\t\t= \"$PUSH\"/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
		sed -i "s/PUSH_URL[[:space:]]*=.*/PUSH_URL\t\t= \"$push_url\"/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
		sed -i "s/PUSH_SECRET[[:space:]]*=.*/PUSH_SECRET\t\t= \"$push_secret\"/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"

		echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/auto.deploy.log"
		chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/auto.deploy.log"

		mkdir "$web_server_dir/$DOMAIN_NAME/auto.deploy/access"
		ssh-keygen -t rsa -f "$web_server_dir/$DOMAIN_NAME/auto.deploy/access/access-key" -N "" > /dev/null 2>&1

		CreateExecutionScript

		chmod -R 750 "$web_server_dir/$DOMAIN_NAME/auto.deploy"
		chown -R www-data:$global_group "$web_server_dir/$DOMAIN_NAME/auto.deploy"

		chmod 400 "$web_server_dir/$DOMAIN_NAME/auto.deploy/access/access-key"
		chmod 775 "$web_server_dir/$DOMAIN_NAME/auto.deploy/access/access-key.pub"
		chmod 700 "$web_server_dir/$DOMAIN_NAME/auto.deploy/index.cgi"

		echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	else
		echo "-> $(tput setaf 1)Fail$(tput sgr 0)"
	fi
}

CreateUnderConstructionPage(){
	echo
	echo "<- Create Under Construction Page"

	sed "s/{domain}/$DOMAIN_NAME/g; " "$local_path/page.templates/index.html" > "$web_server_dir/$DOMAIN_NAME/htdocs/index.html"
	chmod 775 "$web_server_dir/$DOMAIN_NAME/htdocs/index.html"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	echo
}

CreateErrorPages(){
	mkdir "$web_server_dir/$DOMAIN_NAME/error.pages"

	sed "s/{domain}/$DOMAIN_NAME/g; " "$local_path/error.page.templates/404.html" > "$web_server_dir/$DOMAIN_NAME/error.pages/404.html"
	sed "s/{domain}/$DOMAIN_NAME/g; " "$local_path/error.page.templates/50x.html" > "$web_server_dir/$DOMAIN_NAME/error.pages/50x.html"
	sed "s/{domain}/$DOMAIN_NAME/g; " "$local_path/error.page.templates/maintenance.html" > "$web_server_dir/$DOMAIN_NAME/error.pages/maintenance.html"

	chown -R $USER_NAME:$global_group "$web_server_dir/$DOMAIN_NAME/error.pages"
}

GenerateSelfSignedSSL(){
	echo "<- Generate self-signed SSL certificate"

	openssl req -new -x509 -days $certificate_expire_days -nodes -out "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.crt" -keyout "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.key" \
		-subj "/C=$certificate_country/ST=$certificate_state/L=$certificate_locality/O=$certificate_organization/OU=$certificate_unit/CN=$DOMAIN_NAME/emailAddress=$certificate_email" &> /dev/null

	chmod 600 "/etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.key"

	if [ "$IS_SUBDOMAIN" == "N" -o "$IS_SUBDOMAIN" == "n" ]; then
		openssl req -new -x509 -days $certificate_expire_days -nodes -out "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.crt" -keyout "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.key" \
			-subj "/C=$certificate_country/ST=$certificate_state/L=$certificate_locality/O=$certificate_organization/OU=$certificate_unit/CN=www.$DOMAIN_NAME/emailAddress=$certificate_email" &> /dev/null

		chmod 600 "/etc/nginx/ssl/$DOMAIN_NAME/www.$DOMAIN_NAME.key"
	fi

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	echo
}

GenerateCSR(){
	echo "<- Generate CSR"

	if [ -f "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.key" ]; then
		openssl req -new -key "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.key" -out "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.csr" \
			-subj "/C=$certificate_country/ST=$certificate_state/L=$certificate_locality/O=$certificate_organization/OU=$certificate_unit/CN=$DOMAIN_NAME/emailAddress=$certificate_email" &> /dev/null
	else
		openssl req -new -newkey rsa:2048 -nodes -keyout "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.key" -out "$certificate_location/$DOMAIN_NAME/$DOMAIN_NAME.csr" \
			-subj "/C=$certificate_country/ST=$certificate_state/L=$certificate_locality/O=$certificate_organization/OU=$certificate_unit/CN=$DOMAIN_NAME/emailAddress=$certificate_email" &> /dev/null
	fi

	chmod 600 "/etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.key"

	if [ "$IS_SUBDOMAIN" == "N" -o "$IS_SUBDOMAIN" == "n" ]; then
		if [ -f "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.key" ]; then
			openssl req -new -key "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.key" -out "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.csr" \
				-subj "/C=$certificate_country/ST=$certificate_state/L=$certificate_locality/O=$certificate_organization/OU=$certificate_unit/CN=www.$DOMAIN_NAME/emailAddress=$certificate_email" &> /dev/null
		else
			openssl req -new -newkey rsa:2048 -nodes -keyout "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.key" -out "$certificate_location/$DOMAIN_NAME/www.$DOMAIN_NAME.csr" \
				-subj "/C=$certificate_country/ST=$certificate_state/L=$certificate_locality/O=$certificate_organization/OU=$certificate_unit/CN=www.$DOMAIN_NAME/emailAddress=$certificate_email" &> /dev/null
		fi

		chmod 600 "/etc/nginx/ssl/$DOMAIN_NAME/www.$DOMAIN_NAME.key"
	fi

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

SyncToBitbucketIPRange(){
	echo
	echo "<- Sync to Bitbucket IP Range";

	IP_DATA=$(curl -s -X GET "$bitbucket_ip_range_url")

	if [ "$IP_DATA" == "" ]; then
		echo
		echo "$(tput setaf 1) Error: Cannot connect to host: $bitbucket_ip_range_url $(tput sgr 0)"
		echo "$(tput setaf 1) Error: bitbucket.access.conf IP list is out of date!!! $(tput sgr 0)"
	else
		BITBUCKET_IP_LIST=$(echo $IP_DATA | jq -r '.items')

		# Clear old records and add new ones in the correct format
		echo -e "#Bitbucket IP Range\n" > "$local_path/config.templates/nginx/access/bitbucket.access.conf"
		for row in $(echo "${BITBUCKET_IP_LIST}" | jq -r '.[] | @base64'); do
			_jq() {
				echo ${row} | base64 --decode | jq -r ${1}
			}

			echo "allow	$(_jq '.cidr');" >> "$local_path/config.templates/nginx/access/bitbucket.access.conf"
		done

		echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	fi
}

SyncToGitHubIPRange(){
	echo
	echo "<- Sync to GitHub IP Range";

	IP_DATA=$(curl -s https://api.github.com/meta)

	if [ "$IP_DATA" == "" ]; then
		echo
		echo "$(tput setaf 1) Error: Cannot connect to host: https://api.github.com/meta $(tput sgr 0)"
		echo "$(tput setaf 1) Error: github.access.conf IP list is out of date!!! $(tput sgr 0)"
	else
		GITHUB_IP_LIST=$(echo $IP_DATA | jq -r '.hooks[]')

		# Clear old records and add new ones in the correct format
		echo -e "# GitHub IP Range\n" > "$local_path/config.templates/nginx/access/github.access.conf"
		for ip in ${GITHUB_IP_LIST[@]}; do
			# Append properly formatted IPs without any extra characters
			echo "allow $ip;" >> "$local_path/config.templates/nginx/access/github.access.conf"
		done

		echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	fi
}

AddBashLogger(){
	echo
	echo "<- Create Bash logger"

	if git clone https://github.com/lorlev/bash.logger.git "$web_server_dir/$DOMAIN_NAME/log.viewer" > /dev/null 2>&1; then
		chmod -R 775 "$web_server_dir/$DOMAIN_NAME/log.viewer"
		chown -R www-data:$global_group "$web_server_dir/$DOMAIN_NAME/log.viewer"
		echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	else
		echo "-> $(tput setaf 1)Fail$(tput sgr 0)"
	fi
}

NginxAccessStructure(){
	echo
	echo "<- Create Nginx Access Structure"

	if [ ! -d "/etc/nginx/access" ]; then
		mkdir "/etc/nginx/access"
	fi

	if [ ! -d "/etc/nginx/access/$DOMAIN_NAME" ]; then
		mkdir "/etc/nginx/access/$DOMAIN_NAME"
	fi

	#Global Access Lists
	if [ ! -f "/etc/nginx/access/services.access.conf" ]; then
		cp "$local_path/config.templates/nginx/access/services.access.conf" "/etc/nginx/access/services.access.conf"
	fi

	if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
		if [ -f "/etc/nginx/access/github.access.conf" ]; then
			rm "/etc/nginx/access/github.access.conf"
		fi

		if [ -f "/etc/nginx/access/bitbucket.access.conf" ]; then
			rm "/etc/nginx/access/bitbucket.access.conf"
		fi

		if [ -f "/etc/nginx/access/gitlab.access.conf" ]; then
			rm "/etc/nginx/access/gitlab.access.conf"
		fi

		cp "$local_path/config.templates/nginx/access/github.access.conf" "/etc/nginx/access/github.access.conf"
		cp "$local_path/config.templates/nginx/access/bitbucket.access.conf" "/etc/nginx/access/bitbucket.access.conf"
		cp "$local_path/config.templates/nginx/access/gitlab.access.conf" "/etc/nginx/access/gitlab.access.conf"
	fi

	#Domain Access
	cp "$local_path/config.templates/nginx/access/maintenance.access.map" "/etc/nginx/access/$DOMAIN_NAME/maintenance.map"

	if [ "$bash_logger" == "Y" -o "$bash_logger" == "y" ]; then
		cp "$local_path/config.templates/nginx/access/log.viewer.access.conf" "/etc/nginx/access/$DOMAIN_NAME/log.viewer.access.conf"
	fi

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

Finish(){
	echo
	echo "Script execution finished."
	exit 0
}

