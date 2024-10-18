#!/bin/sh

AskServiceRequirements(){
	if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
		#Composer
		if [ "$composer_build" == "Y" -o "$composer_build" == "y" ]; then
			read -e -p "Is Composer? (Y/n) (default y): " COMPOSER
			if [ -z "$COMPOSER" ]; then
				COMPOSER='y'
			fi
			echo
		else
			COMPOSER='n'
		fi
	fi
}

CreateLogs(){
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/php.error.log"
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/php.slow.log"
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/php.access.log"

	if [ "$COMPOSER" == "Y" -o "$COMPOSER" == "y" ]; then
		echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/composer.output.log"
		echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/artisan.output.log"
	fi

	chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/php.error.log"
	chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/php.slow.log"
	chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/php.access.log"

	if [ "$COMPOSER" == "Y" -o "$COMPOSER" == "y" ]; then
		chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/composer.output.log"
		chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/artisan.output.log"
	fi

	chmod -R 775 "$web_server_dir/$DOMAIN_NAME/server.logs"
}

CreateDirs(){
	echo
	echo "<- Create php session directory"

	chown www-data:$global_group "/var/lib/php/session"
	mkdir "/var/lib/php/session/$DOMAIN_NAME"
	chmod 770 "/var/lib/php/session/$DOMAIN_NAME"
	chown www-data:$global_group "/var/lib/php/session/$DOMAIN_NAME"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"

	echo
	echo "<- Create php wsdlcache directory"

	chown www-data:$global_group "/var/lib/php/wsdlcache"
	mkdir "/var/lib/php/wsdlcache/$DOMAIN_NAME"
	chmod 770 "/var/lib/php/wsdlcache/$DOMAIN_NAME"
	chown www-data:$global_group "/var/lib/php/wsdlcache/$DOMAIN_NAME"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	echo
}

CreateExecutionScript(){
	sed -i "s/COMPOSER[[:space:]]*=.*/COMPOSER\t\t= \"$COMPOSER\"/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
	sed -i "s/TECH[[:space:]]*=.*/TECH\t\t\t= \"$TECHNOLOGY\"/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
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
	PROJECT=$DOMAIN_NAME

	if [ $GIT_BRANCH = "test" ] && [ "$IS_SUBDOMAIN" == "Y" -o "$IS_SUBDOMAIN" == "y" ]; then
		PROJECT=${DOMAIN_NAME//test./}
	fi

	echo
	echo "<- Create PHP-FPM Config file"
	sed "s/{domain}/$DOMAIN_NAME/g; s/{project_name}/$PROJECT/g; s/{branch}/$GIT_BRANCH/g; s/{port}/$fpm_port/g; s/{user}/$USER_NAME/g; s/{group}/$global_group/g; s|{web_server_dir}|$web_server_dir|g" config.templates/php/fpm.conf > "$php_fpm_pool_location/$DOMAIN_NAME.conf"
	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

ExecuteScript(){
	if [ "$COMPOSER" == "Y" -o "$COMPOSER" == "y" ]; then
		if [ -f "$web_server_dir/$DOMAIN_NAME/htdocs/composer.json" ]; then
			echo
			echo "Composer install"

			export HOME=$web_server_dir/$DOMAIN_NAME
			export COMPOSER_HOME=$web_server_dir/$DOMAIN_NAME/.composer

			/usr/bin/php \
				-d allow_url_fopen=1 \
				-d disable_functions= \
				-d suhosin.executor.include.whitelist=phar \
				/usr/local/bin/composer \
					install \
					--profile \
					--no-interaction \
					--prefer-dist \
					--no-ansi \
					--optimize-autoloader \
					--no-dev \
					--working-dir="$web_server_dir/$DOMAIN_NAME/htdocs"

			chown -R www-data:$global_group "$web_server_dir/$DOMAIN_NAME/.composer"
			rm "$web_server_dir/$DOMAIN_NAME/.pki" -rf
		fi
	fi
}

RestartService(){
	/bin/systemctl restart php-fpm.service
}

GetServiceSummary(){
	echo "-> PHP-FPM Port is: $fpm_port"
}

