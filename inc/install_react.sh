#!/bin/sh

AskServiceRequirements(){
	echo
}

CreateLogs(){
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/php.error.log"
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/php.slow.log"
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/php.access.log"

	chown nginx:sftpusers "$web_server_dir/$DOMAIN_NAME/server.logs/php.error.log"
	chown nginx:sftpusers "$web_server_dir/$DOMAIN_NAME/server.logs/php.slow.log"
	chown nginx:sftpusers "$web_server_dir/$DOMAIN_NAME/server.logs/php.access.log"

	chmod -R 775 "$web_server_dir/$DOMAIN_NAME/server.logs"
}

CreateDirs(){
	echo
	echo "<- Create php session directory"

	chown nginx:sftpusers "/var/lib/php/session"
	mkdir "/var/lib/php/session/$DOMAIN_NAME"
	chmod 770 "/var/lib/php/session/$DOMAIN_NAME"
	chown nginx:sftpusers "/var/lib/php/session/$DOMAIN_NAME"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"

	echo
	echo "<- Create php wsdlcache directory"

	chown nginx:sftpusers "/var/lib/php/wsdlcache"
	mkdir "/var/lib/php/wsdlcache/$DOMAIN_NAME"
	chmod 770 "/var/lib/php/wsdlcache/$DOMAIN_NAME"
	chown nginx:sftpusers "/var/lib/php/wsdlcache/$DOMAIN_NAME"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

CreateExecutionScript(){
	echo
}

CreateConfig(){
	# Check fpm port file
	if [ ! -f "$local_path/tmp/max_fpm_port.ini" ]; then
		echo "<- Create FPM Port iterator file"
		echo 'fpm_port=9000' > "$local_path/tmp/max_fpm_port.ini"
		echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	fi

	source "$local_path/tmp/max_fpm_port.ini"

	# Increment port
	sed -i "s/^fpm_port=[^ ]*/fpm_port=$((fpm_port+1))/" "$local_path/tmp/max_fpm_port.ini"

	echo
	echo "<- Create PHP-FPM Config file"
	sed "s/{domain}/$DOMAIN_NAME/g; s/{port}/$fpm_port/g; s/{user}/$USER_NAME/g; s/{group}/$global_group/g; s|{web_server_dir}|$web_server_dir|g" config.templates/php/fpm.conf > "$php_fpm_pool_location/$DOMAIN_NAME.conf"
	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

ExecuteScript(){
	echo
}

RestartService(){
	/bin/systemctl restart php-fpm.service
}

GetServiceSummary(){
	echo "-> PHP-FPM Port is: $fpm_port"
}

