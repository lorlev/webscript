#!/bin/bash


TECH_MAIN_ROOT_DIR=$(cat <<EOF
	root                      $web_server_dir/$DOMAIN_NAME/htdocs/public;
EOF
)

TECH_ROOT_LOCATION=$(cat <<EOF

	location / {
		if (\$$DOMAIN_NAME.maintenance = on) {
			return                    503;
		}

		index                     index.php index.html;

		try_files                 \$uri \$uri/ /index.php?\$args;
		if (!-e \$request_filename){
			rewrite                   ^/(.*)\$ /index.php?url=\$1 last;
		}
	}\n

EOF
)

NGINX_TECH_LOCATION=$(cat <<EOF

	location ~ \.php\$ {
		if (\$$DOMAIN_NAME.maintenance = on) {
			return                    503;
		}

		fastcgi_index             index.php;
		fastcgi_pass              127.0.0.1:$fpm_port;
		fastcgi_param             SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include                   fastcgi_params;
	}\n

EOF
)

NGINX_TECT_STATUS=$(cat <<EOF

	location ~ ^/(status|ping)$ {
		include                   /etc/nginx/access/services.access.conf;
		deny                      all;
		access_log                off;

		fastcgi_pass              127.0.0.1:$fpm_port;
		fastcgi_param             SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include                   fastcgi_params;
	}\n

EOF
)