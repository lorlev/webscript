#!/bin/bash

##
##SSL and Subdomain block
##
if [ "$IS_SUBDOMAIN" == "Y" -o "$IS_SUBDOMAIN" == "y" ]; then
	#### Sub Domain
	####
	if [ "$IS_SSL" == "Y" -o "$IS_SSL" == "y" ]; then
		####
		NGINX_REDIRECT_TO_WWW=$(cat <<EOF

server {
	listen                    80;
	server_name               $DOMAIN_NAME;
	return                    301 https://$DOMAIN_NAME\$request_uri;
}\n

EOF
)
		##
		NGINX_MAIN_LISTEN=$(cat <<EOF
	listen                    443 ssl;
	server_name               $DOMAIN_NAME;

	ssl_certificate           /etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.crt;
	ssl_certificate_key       /etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.key;
	ssl_protocols             TLSv1.2;

	ssl_session_cache         shared:SSL:1m;
	ssl_session_timeout       5m;

	ssl_ciphers               HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers on;

	add_header                Strict-Transport-Security "max-age=31536000";
EOF
)
		####
	else
		NGINX_REDIRECT_TO_WWW=''
		####
		NGINX_MAIN_LISTEN=$(cat <<EOF
	listen                    80;
	server_name               $DOMAIN_NAME;
EOF
)
	fi
	####
else
	#### Domain
	####
	if [ "$IS_SSL" == "Y" -o "$IS_SSL" == "y" ]; then
		####
		NGINX_REDIRECT_TO_WWW=$(cat <<EOF

server {
	listen                    80;
	server_name               $DOMAIN_NAME www.$DOMAIN_NAME;
	return                    301 https://www.$DOMAIN_NAME\$request_uri;
}

server {
	listen                    443 ssl;
	server_name               $DOMAIN_NAME;

	ssl_certificate           /etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.crt;
	ssl_certificate_key       /etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.key;
	ssl_protocols             TLSv1.2;

	ssl_session_cache         shared:SSL:1m;
	ssl_session_timeout       5m;

	ssl_ciphers               HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers on;

	add_header                Strict-Transport-Security "max-age=31536000";

	return                    301 https://www.$DOMAIN_NAME\$request_uri;
}\n

EOF
)
		##
		NGINX_MAIN_LISTEN=$(cat <<EOF
	listen                    443 ssl;
	server_name               www.$DOMAIN_NAME;

	ssl_certificate           /etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.crt;
	ssl_certificate_key       /etc/nginx/ssl/$DOMAIN_NAME/$DOMAIN_NAME.key;
	ssl_protocols             TLSv1.2;

	ssl_session_cache         shared:SSL:1m;
	ssl_session_timeout       5m;

	ssl_ciphers               HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers on;

	add_header                Strict-Transport-Security "max-age=31536000";
EOF
)
		####
	else
		####
		NGINX_REDIRECT_TO_WWW=$(cat <<EOF

server {
	listen                    80;
	server_name               $DOMAIN_NAME;
	return                    301 http://www.$DOMAIN_NAME\$request_uri;
}\n

EOF
)
		##
		NGINX_MAIN_LISTEN=$(cat <<EOF
	listen                    80;
	server_name               www.$DOMAIN_NAME;
EOF
)
		####
	fi
	####
fi

##
##end of SSL and Subdomain block
##

if [ "$AUTO_DEPLOY" == "Y" -o "$AUTO_DEPLOY" == "y" ]; then
	####
	NGINX_AUTO_DEPLOY=$(cat <<EOF


	location = /auto.deploy {
		include                   /etc/nginx/access/services.access.conf;
		include                   /etc/nginx/access/github.access.conf;
		include                   /etc/nginx/access/bitbucket.access.conf;
		include                   /etc/nginx/access/gitlab.access.conf;
		deny                      all;
		access_log                off;

		gzip                      off;
		auth_basic                off;

		# Define the root directory
		root                      $web_server_dir/$DOMAIN_NAME;

		# Serve the index.cgi script directly without redirecting
		try_files                 /auto.deploy/index.cgi =404;

		# FastCGI configuration to process the CGI script
		include                   fastcgi_params;
		fastcgi_param             SCRIPT_FILENAME \$document_root/auto.deploy/index.cgi;
		fastcgi_pass              unix:/var/run/fcgiwrap.socket;
	}\n

EOF
)
	####
fi

if [ "$bash_logger" == "Y" -o "$bash_logger" == "y" ]; then
	####
	NGINX_LOG_VIEWER=$(cat <<EOF

	location ^~ /log.viewer {
		include                   /etc/nginx/access/services.access.conf;
		include                   /etc/nginx/access/$DOMAIN_NAME/log.viewer.access.conf;
		deny                      all;
		access_log                off;

		index                     index.cgi;
		root                      $web_server_dir/$DOMAIN_NAME;
		gzip                      off;
		auth_basic                off;

		try_files                 \$uri \$uri/ /log.viewer/index.cgi?\$args;
		if (!-e \$request_filename){
			rewrite                   ^/(.*)$ /log.viewer/index.cgi?url=\$1 last;
		}

		location ~ \.cgi$ {
			try_files                 \$uri = 404;
			include                   fastcgi_params;

			fastcgi_param             SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
			fastcgi_pass              unix:/var/run/fcgiwrap.socket;
		}
	}\n

EOF
)
	####
fi