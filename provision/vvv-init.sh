#!/usr/bin/env bash
# Provision WordPress Stable

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
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
define( 'SCRIPT_DEBUG', true );
define( 'RKV_DEV_MODE', true );
define( 'JETPACK_DEV_DEBUG', true );
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

  echo "Deleting Hello Dolly..."

  # And delete it.
  rm "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/hello.php"
fi

# Add my assets folder
if [[ ! -f "${VVV_PATH_TO_SITE}/assets" ]]; then

  echo "Creating assets folder..."

  # Create my MU plugins folder
  mkdir -p "${VVV_PATH_TO_SITE}/assets"

fi

# Add my MU plugins folder
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins" ]]; then

  echo "Creating MU plugins folder..."

  # Create my MU plugins folder
  mkdir -p "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins"

fi

# Add my debug tools file
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins/norcross-debug-functions.php" ]]; then

  echo "Adding Norcross debug functions..."

  # clone the gist
  git clone "https://gist.github.com/7864205.git" "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins/"

fi

# Copy over my API keys file from local
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins/norcross-api-keys.php" ]]; then

  echo "Adding API keys file..."

  # copy the file from local
  cp -a "/srv/config/custom/mu-plugins/norcross-api-keys.php" "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins/norcross-api-keys.php"

fi

# Create my scratchpad file from local.
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins/norcross-scratchpad.php" ]]; then

  echo "Adding dev scratchpad file..."

  # copy the file from local
  cp -a "/srv/config/custom/mu-plugins/norcross-scratchpad.php" "${VVV_PATH_TO_SITE}/public_html/wp-content/mu-plugins/norcross-scratchpad.php"
fi

# Add Airplane Mode
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/airplane-mode/airplane-mode.php" ]]; then

  echo "Adding Airplane Mode..."

  # Install the plugin using WP-CLI
  noroot wp plugin install airplane-mode

fi

# Add Query Monitor
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/query-monitor/query-monitor.php" ]]; then

  echo "Adding Query Monitor..."

  # Install the plugin using WP-CLI
  noroot wp plugin install query-monitor --activate

fi

# Add WP Sweep
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/wp-sweep/wp-sweep.php" ]]; then

  echo "Adding WP Sweep..."

  # Install the plugin using WP-CLI
  noroot wp plugin install wp-sweep --activate

fi

# Add WP Classic Editor
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/classic-editor/classic-editor.php" ]]; then

  echo "Adding Classic Editor..."

  # Install the plugin using WP-CLI
  noroot wp plugin install classic-editor --activate

fi

# Add CMB2
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/cmb2/index.php" ]]; then

  echo "Adding CMB2..."

  # Install the plugin using WP-CLI
  noroot wp plugin install cmb2

fi

# Add my regular plugins
#if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins/airplane-mode/airplane-mode.php" ]]; then

  #echo "Adding additional plugins..."

  # copy over the MU plugins folder
  #cp -a "/vagrant/setup/plugins/." "${VVV_PATH_TO_SITE}/public_html/wp-content/plugins"
#fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{DOMAINS_HERE}}#${DOMAINS}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
