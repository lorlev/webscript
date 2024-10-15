#!/bin/bash


TECH_MAIN_ROOT_DIR=$(cat <<EOF
	root                      $web_server_dir/$DOMAIN_NAME/htdocs;
EOF
)

TECH_ROOT_LOCATION=$(cat <<EOF

	location / {
		if (\$$DOMAIN_NAME.maintenance = on) {
			return                    503;
		}

		proxy_pass                "http://localhost:$gunicorn_port/";

		proxy_set_header          X-Real-IP \$remote_addr;
		proxy_set_header          Host \$host;
		proxy_set_header          X-Forwarded-For \$proxy_add_x_forwarded_for;

		proxy_http_version        1.1;
		proxy_set_header          Upgrade \$http_upgrade;
		proxy_set_header          Connection "upgrade";
	}\n

EOF
)