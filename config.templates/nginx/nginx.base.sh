#!/bin/bash

source "$local_path/config.templates/nginx/nginx.blocks.sh"
source "$local_path/config.templates/nginx/tech/$TECHNOLOGY.template.sh"

NGINX_BASE_CONFIG=$(cat <<EOF
map \$remote_addr \$$DOMAIN_NAME.maintenance {
	include                   /etc/nginx/access/$DOMAIN_NAME/maintenance.map;
}
$NGINX_REDIRECT_TO_WWW
server {
$NGINX_MAIN_LISTEN

$TECH_MAIN_ROOT_DIR

	charset                   UTF-8;

	access_log                off;
	#access_log                $web_server_dir/$DOMAIN_NAME/server.logs/nginx.access.log main;
	error_log                 $web_server_dir/$DOMAIN_NAME/server.logs/nginx.error.log;
$TECH_ROOT_LOCATION
	error_page                404 /404.html;
	location = /404.html {
		root                      $web_server_dir/$DOMAIN_NAME/error.pages;
	}

	error_page 500 502 504 /50x.html;
	location = /50x.html {
		root                      $web_server_dir/$DOMAIN_NAME/error.pages;
	}

	error_page 503 /maintenance.html;
	location = /maintenance.html {
		root                      $web_server_dir/$DOMAIN_NAME/error.pages;
	}
$NGINX_TECH_LOCATION $NGINX_AUTO_DEPLOY $NGINX_LOG_VIEWER
	location = /stat {
		include                   /etc/nginx/access/services.access.conf;
		deny                      all;
		access_log                off;

		stub_status               on;
	}
$NGINX_TECT_STATUS
	location ~* ".+\.(?:ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|rss|css|swf|js|atom|jpe?g|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)$" {
		access_log                off;
		log_not_found             off;
		expires                   30d;
		add_header Cache-Control "public, no-transform";
	}

	location ~ /\. {
		access_log                off;
		log_not_found             off;
		deny                      all;
	}

	location ~* \.(ht|svn|git|hg|bzr|sh|sql|env)$ {
		deny                      all;
	}

	#SublimeText sftp plugin
	location ^~ /sftp-config.json {
		deny                      all;
	}
}

EOF
)