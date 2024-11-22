#!/bin/sh

AskServiceRequirements(){
	read -e -p "Gunicorn Service Title (*): " SERVICE_TITLE
	if [ -z "$SERVICE_TITLE" ]; then
		echo
		echo "$(tput setaf 1) Error: Gunicorn Service Name is empty $(tput sgr 0)"
		exit 0
	fi
	echo
}

CreateLogs(){
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/gunicorn.output.log"
	echo "" > "$web_server_dir/$DOMAIN_NAME/server.logs/pip.install.output.log"

	chmod 775 "$web_server_dir/$DOMAIN_NAME/server.logs/gunicorn.output.log"
	chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/gunicorn.output.log"
	chown www-data:$global_group "$web_server_dir/$DOMAIN_NAME/server.logs/pip.install.output.log"
}

CreateDirs(){
	echo
	echo "<- Create pip cache directory"

	mkdir "$web_server_dir/$DOMAIN_NAME/.pip"
	mkdir "$web_server_dir/$DOMAIN_NAME/.pip/cache"

	chown -R www-data:$global_group "$web_server_dir/$DOMAIN_NAME/.pip"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

CreateExecutionScript(){
	sed -i "s/RUN_GUNICORN[[:space:]]*=.*/RUN_GUNICORN\t\t= $RUN_GUNICORN/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
	sed -i "s/TECH[[:space:]]*=.*/TECH\t\t\t= $TECHNOLOGY/" "$web_server_dir/$DOMAIN_NAME/auto.deploy/.env"
}

CreateConfig(){
	# Check gunicorn port file
	if [ ! -f "$local_path/tmp/max_gunicorn_port.ini" ]; then
		echo "<- Create Gunicorn Port iterator file"
		echo 'gunicorn_port=8000' > "$local_path/tmp/max_gunicorn_port.ini"
		echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
	fi

	source "$local_path/tmp/max_gunicorn_port.ini"

	# Increment port
	sed -i "s/^gunicorn_port=[^ ]*/gunicorn_port=$((gunicorn_port+1))/" "$local_path/tmp/max_gunicorn_port.ini"

	SERVICE_NAME="${DOMAIN_NAME%.*}"

	echo
	echo "<- Create Gunicorn Service file"

	sed "s/{domain}/$DOMAIN_NAME/g; s/{service_title}/$SERVICE_TITLE/g; s/{gunicorn_port}/$gunicorn_port/g; s/{user}/$USER_NAME/g; s/{group}/$global_group/g; s|{web_server_dir}|$web_server_dir|g" config.templates/python/gunicorn.service > "/etc/systemd/system/$SERVICE_NAME.service"

	echo "-> $(tput setaf 2)Ok$(tput sgr 0)"
}

ExecuteScript(){
	if [ -f "$web_server_dir/$DOMAIN_NAME/htdocs/requirements.txt" ]; then
		echo
		echo "Sync Python requirements"

		virtualenv "$web_server_dir/$DOMAIN_NAME/htdocs"

		export HOME=$web_server_dir/$DOMAIN_NAME
		source "$web_server_dir/$DOMAIN_NAME/htdocs/bin/activate"

		pip install \
			-r "$web_server_dir/$DOMAIN_NAME/htdocs/requirements.txt" \
			--cache-dir "$web_server_dir/$DOMAIN_NAME/.pip/cache"

	fi
}

RestartService(){
	/bin/systemctl daemon-reload
	/bin/systemctl restart "$SERVICE_NAME.service"
	/bin/systemctl enable "$SERVICE_NAME.service"
}

GetServiceSummary(){
	echo "-> Gunicorn Port is: $gunicorn_port"
	echo "-> Gunicorn Service Name is: $SERVICE_NAME"
	echo "-> Gunicorn Service Path is: /etc/systemd/system/$SERVICE_NAME.service"
}
