#!/usr/bin/env bash
# Provision WordPress Stable

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".dev`
DOMAINS=`get_hosts "${DOMAIN}"`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-load.php" ]]; then
    echo "Downloading WordPress..."
	noroot wp core download --version="${WP_VERSION}"
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'RKV_DEV_MODE', true );
define ('JETPACK_DEV_DEBUG', true);
PHP
fi

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="norcrossadmin@gmail.com" --admin_password="password"
else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core update --version="${WP_VERSION}"
fi

# Some stuff below requires the vagrant-scp plugin

# Delete Hello Dolly
if [[ -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/hello.php" ]]; then

  echo "Deleting Helly Dolly..."

  # And delete it.
  rm "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/hello.php"
fi

# Add my MU plugins
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins" ]]; then

  echo "Adding MU plugins..."

  # Create my MU plugins folder
  mkdir -p ${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins

  # copy over the MU plugins folder
  cp -a "./setup/mu-plugins/." "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins"
fi

# Add my regular plugins
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/airplane-mode/airplane-mode.php" ]]; then

  echo "Adding additional plugins..."

  # copy over the MU plugins folder
  cp -a "./setup/plugins/." "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{DOMAINS_HERE}}#${DOMAINS}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
