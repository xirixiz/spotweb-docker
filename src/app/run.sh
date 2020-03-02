#!/usr/bin/env bash
#set -o errexit
#set -o pipefail
#set -o nounset

#---------------------------------------------------------------------------------------------------------------------------
# VARIABLES
#---------------------------------------------------------------------------------------------------------------------------
: "${DEBUG:=false}"
: "${COMMAND:=$@}"
: "${WEBCONF:=/etc/apache2/conf.d/spotweb.conf}"
: "${SSLWEBCONF:=/etc/apache2/conf.d/spotweb_ssl.conf}"
: "${WEBDIR:=/var/www/spotweb}"

#---------------------------------------------------------------------------------------------------------------------------
# FUNCTIONS
#---------------------------------------------------------------------------------------------------------------------------
function _info  () { printf "\\r[ \\033[00;34mINFO\\033[0m ] %s\\n" "$@"; }
function _warn  () { printf "\\r\\033[2K[ \\033[0;33mWARN\\033[0m ] %s\\n" "$@"; }
function _error () { printf "\\r\\033[2K[ \\033[0;31mFAIL\\033[0m ] %s\\n" "$@"; }
function _debug () { printf "\\r[ \\033[00;37mDBUG\\033[0m ] %s\\n" "$@"; }

function _override_entrypoint() {
  if [[ -n "${COMMAND}" ]]; then
    _info "ENTRYPOINT: Executing override command..."
    exec "${COMMAND}"
  fi
}

function _set_configure_apache() {
  case ${SSL} in
    enabled)
      _info "Deploying apache config with SSL support:"
      cat <<EOF > ${SSLWEBCONF}
<VirtualHost 0.0.0.0:443>
    ServerAdmin _

    SSLEngine on
    SSLCertificateFile "/etc/ssl/web/spotweb.crt"
    SSLCertificateKeyFile "/etc/ssl/web/spotweb.key"
    SSLCertificateChainFile "/etc/ssl/web/spotweb.chain.crt"

    DocumentRoot ${WEBDIR}
    <Directory ${WEBDIR}/>
        RewriteEngine on
        RewriteCond %{REQUEST_URI} !api/
        RewriteRule ^api/?$ index.php?page=newznabapi [QSA,L]
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
    chown apache: ${SSLWEBCONF}
    chmod 600 /etc/ssl/web/*
    apk add apache2-ssl
    ;;

    *)
      _info "Deploying apache config without SSL support:"
  esac

  cat <<EOF > ${WEBCONF}
<VirtualHost 0.0.0.0:80>
    ServerAdmin _

    DocumentRoot ${WEBDIR}
    <Directory ${WEBDIR}/>
        RewriteEngine on
        RewriteCond %{REQUEST_URI} !api/
        RewriteRule ^api/?$ index.php?page=newznabapi [QSA,L]
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
  chown apache: ${WEBCONF}
}

function _set_defaults() {
  sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/apache2/httpd.conf
  sed -i "s/#ServerName www.example.com/ServerName $(hostname)/g" /etc/apache2/httpd.conf
  echo "date.timezone = ${TZ}" >> /etc/php7/php.ini
}

function _set_database_type() {
  _info "Installing ${SQL} support:"
  case ${SQL} in
    sqlite)
      apk add php7-pdo_sqlite
    ;;

    psql)
      apk add php7-pgsql php7-pdo_pgsql
    ;;

    mysql)
      apk add php7-mysqlnd php7-pdo_mysql
    ;;

    *)
      _info "Option SQL=${SQL} invalid, use sqlite, psql or mysql!"
    ;;
  esac
}

function _set_permissions() {
  if [[ ! -z ${UUID} ]]
  then
    _info "Replacing old apache UID with ${UUID}"
    OldUID=$(getent passwd apache | cut -d ':' -f3)
    usermod -u ${UUID} apache
    find / -user ${OldUID} -exec chown -h apache {} \; &> /dev/null
  fi

  if [[ ! -z ${GUID} ]]
  then
    _info "Replacing old apache GID with ${GUID}"
    OldGID=$(getent passwd apache | cut -d ':' -f4)
    groupmod -g ${GUID} apache
    find / -group ${OldGID} -exec chgrp -h apache {} \; &> /dev/null
  fi

  chown -R apache: ${WEBDIR}
}

function _cleanup() {
  _info "Cleanup temp files..."
  rm -rf /var/cache/apk/* && \
}

function _start_spotweb() {
  _info "Starting Spotweb..."
  /usr/sbin/httpd -D FOREGROUND -f /etc/apache2/httpd.conf
}

#---------------------------------------------------------------------------------------------------------------------------
# MAIN
#---------------------------------------------------------------------------------------------------------------------------
[[ "${DEBUG}" == 'true' ]] && set -o xtrace

_override_entrypoint
_set_configure_apache
_set_defaults
_set_database_type
_set_permissions
_cleanup
_start_spotweb