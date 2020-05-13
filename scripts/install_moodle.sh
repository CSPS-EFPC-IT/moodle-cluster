#!/bin/bash
# This script must be run as root (ex.: sudo sh [script_name])

function echo_title {
    echo ""
    echo "###############################################################################"
    echo "$1"
    echo "###############################################################################"
}

###############################################################################
echo_title "Starting $0 on $(date)."
###############################################################################

###############################################################################
echo_title "Map input parameters."
###############################################################################
storageAccountName="$1"
storageAccountKey="$2"
fileShareName="$3"
dbServerName="$4"
dbServerAdminUsername="$5"
dbServerAdminPassword="$6"
moodleDbName="$7"
moodleDbUsername="$8"
moodleDbPassword="$9"
shift 9
moodleDnsName="$1"
moodleAdminUsername="$2"
moodleAdminPassword="$3"
moodleAdminEmail="$4"
redisName="$5"
redisPassword="$6"
moodleUpgradeKey="$7"
echo "Done."

###############################################################################
echo_title "Echo parameter values for debuging purpose."
###############################################################################
echo "storageAccountName=${storageAccountName}"
echo "storageAccountKey=${storageAccountKey}"
echo "fileShareName=${fileShareName}"
echo "dbServerName=${dbServerName}"
echo "dbServerAdminUsername=${dbServerAdminUsername}"
echo "dbServerAdminPassword=${dbServerAdminPassword}"
echo "moodleDbName=${moodleDbName}"
echo "moodleDbUsername=${moodleDbUsername}"
echo "moodleDbPassword=${moodleDbPassword}"
echo "moodleDnsName=${moodleDnsName}"
echo "moodleAdminUsername=${moodleAdminUsername}"
echo "moodleAdminPassword=${moodleAdminPassword}"
echo "moodleAdminEmail=${moodleAdminEmail}"
echo "redisName=${redisName}"
echo "redisPassword=${redisPassword}"
echo "Done."

###############################################################################
echo_title "Set useful variables."
###############################################################################
phpIniPath="/etc/php/7.2/apache2/php.ini"
defaultDocumentRoot=/var/www/html
apache2User="www-data"
moodleDocumentRoot=${defaultDocumentRoot}/moodle
moodleLocalCacheRoot=${defaultDocumentRoot}/moodlelocalcache
installDir=$(pwd)
echo "Done."

###############################################################################
echo_title "Update and upgrade the server."
###############################################################################
apt-get update
apt-get upgrade -y
apt-get autoremove -y
echo "Done."

###############################################################################
echo_title "Install tools."
###############################################################################
apt-get install postgresql-client-10 php-cli unzip -y
echo "Done."

###############################################################################
echo_title "Install Moodle dependencies."
###############################################################################
apt-get install apache2 postgresql-client-10 libapache2-mod-php -y
apt-get install graphviz aspell ghostscript clamav php7.2-pspell php7.2-curl php7.2-gd php7.2-intl php7.2-pgsql php7.2-xml php7.2-xmlrpc php7.2-ldap php7.2-zip php7.2-soap php7.2-mbstring php7.2-redis -y
echo "Done."

###############################################################################
echo_title "Update PHP config."
###############################################################################
echo "Update upload_max_filesize setting."
sed -i "s/upload_max_filesize.*/upload_max_filesize = 2048M/" $phpIniPath
echo "Update post_max_size setting."
sed -i "s/post_max_size.*/post_max_size = 2048M/" $phpIniPath
echo "Done."

###############################################################################
echo_title "Update Apache default site DocumentRoot property."
###############################################################################
if ! grep -q "${moodleDocumentRoot}" /etc/apache2/sites-available/000-default.conf; then
    echo "Updating /etc/apache2/sites-available/000-default.conf..."
    escapedDefaultDocumentRoot=$(sed -E 's/(\/)/\\\1/g' <<< ${defaultDocumentRoot})
    escapedMoodleDocumentRoot=$(sed -E 's/(\/)/\\\1/g' <<< ${moodleDocumentRoot})
    sed -i -E "s/DocumentRoot[[:space:]]*${escapedDefaultDocumentRoot}/DocumentRoot ${escapedMoodleDocumentRoot}/g" /etc/apache2/sites-available/000-default.conf
    echo "Restarting Apache2..."
    service apache2 restart
else
    echo "Skipping /etc/apache2/sites-available/000-default.conf file update."
fi
echo "Done."

###############################################################################
echo_title "Create Moodle database user if not existing."
###############################################################################
echo "Creating and granting privileges to database user ${moodleDbUsername}..."
psql "host=${dbServerName}.postgres.database.azure.com port=5432 dbname=postgres user=${dbServerAdminUsername}@${dbServerName} password=${dbServerAdminPassword} sslmode=require" << EOF
DO \$\$
BEGIN
    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE rolname='${moodleDbUsername}' ) THEN
        create user ${moodleDbUsername} with encrypted password '${moodleDbPassword}';
        grant all privileges on database ${moodleDbName} to ${moodleDbUsername};
        RAISE NOTICE 'User ${moodleDbUsername} created.';
    ELSE
      RAISE WARNING 'The user ${moodleDbUsername} was already existing.';
    END IF;
END
\$\$;
EOF
echo "Done."

###############################################################################
echo_title "Mount Moodle data fileshare."
###############################################################################
if [ ! -d "/mnt/${fileShareName}" ]; then
    echo "Creating /mnt/${fileShareName} folder..."
    mkdir /mnt/${fileShareName}
else
    echo "Skipping /mnt/${fileShareName} creation."
fi
if [ ! -d "/etc/smbcredentials" ]; then
    echo "Creating /etc/smbcredentials folder..."
    mkdir /etc/smbcredentials
else
    echo "Skipping /etc/smbcredentials file creation."
fi
if [ ! -f "/etc/smbcredentials/openlearningmoodlesa.cred" ]; then
    echo "Creating /etc/smbcredentials/openlearningmoodlesa.cred file..."
    echo "username=${storageAccountName}" >> /etc/smbcredentials/${storageAccountName}.cred
    echo "password=${storageAccountKey}" >> /etc/smbcredentials/${storageAccountName}.cred
else
    echo "Skipping /etc/smbcredentials/openlearningmoodlesa.cred file creation."
fi
echo "Updating permission on /etc/smbcredentials/${storageAccountName}.cred..."
chmod 600 /etc/smbcredentials/${storageAccountName}.cred
if ! grep -q ${storageAccountName} /etc/fstab; then
    echo "Updating /etc/fstab file..."
    echo "//${storageAccountName}.file.core.windows.net/${fileShareName} /mnt/${fileShareName} cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
else
    echo "Skipping /etc/fstab file update."
fi
echo "Mounting /mnt/${fileShareName} folder..."
mount -t cifs //${storageAccountName}.file.core.windows.net/${fileShareName} /mnt/${fileShareName} -o vers=3.0,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino
echo "Done."

###############################################################################
echo_title "Create Moodle Local Cache directory."
###############################################################################
if [ -d ${moodleLocalCacheRoot} ]; then
    echo "Deleting old ${moodleLocalCacheRoot} folder..."
    rm -rf ${moodleLocalCacheRoot}
fi
echo "Creating new ${moodleLocalCacheRoot} folder..."
mkdir ${moodleLocalCacheRoot}
echo "Updating file permission on ${moodleLocalCacheRoot}..."
chown -R ${apache2User} ${moodleLocalCacheRoot}
echo "Done."

###############################################################################
echo_title "Download and extract Moodle files and plugins."
###############################################################################
echo "Downloading latest Moodle 3.8 zip file..."
wget https://download.moodle.org/download.php/direct/stable38/moodle-latest-38.tgz --output-document moodle-latest-38.tgz
echo "Extracting moodle zip file..."
if [ -d ${moodleDocumentRoot} ]; then
    echo "Deleting old ${moodleDocumentRoot} folder..."
    rm -rf ${moodleDocumentRoot}
fi
tar zxf moodle-latest-38.tgz -C ${defaultDocumentRoot}

# echo "Downloading WebEx Meeting plugin..."
# wget https://moodle.org/plugins/download.php/20750 --output-document mod_webexactivity_moodle38_latest.zip
# echo "Extracting WebEx Meeting plugin..."
# unzip mod_webexactivity_moodle38_latest.zip -d ${moodleDocumentRoot}/mod

echo "Downloading Multi-Language Content (v2) plugin zip file..."
wget https://moodle.org/plugins/download.php/20674/filter_multilang2_moodle38_2019111900.zip
echo "Extracting Multi-Language Content (v2) plugin..."
unzip filter_multilang2_moodle38_2019111900.zip -d ${moodleDocumentRoot}/filter


echo "Downloading BigBlueButtonBN plugin zip file..."
wget https://moodle.org/plugins/download.php/21195/mod_bigbluebuttonbn_moodle38_2019042008.zip
echo "Extracting BigBlueButtonBN plugin..."
unzip mod_bigbluebuttonbn_moodle38_2019042008.zip -d ${moodleDocumentRoot}/mod

echo "Downloading Navbar Plus plugin zip file..."
wget https://moodle.org/plugins/download.php/21066/local_navbarplus_moodle38_2020021800.zip
echo "Extracting Navbar Plus Package plugin..."
unzip local_navbarplus_moodle38_2020021800.zip -d ${moodleDocumentRoot}/local

echo "Downloading QR code plugin zip file..."
wget https://moodle.org/plugins/download.php/20732/block_qrcode_moodle38_2019112100.zip
echo "Extracting QR code plugin..."
unzip block_qrcode_moodle38_2019112100.zip -d ${moodleDocumentRoot}/blocks

echo "Downloading Facetoface plugin zip file..."
wget https://moodle.org/plugins/download.php/18183/mod_facetoface_moodle35_2018110900.zip
echo "Extracting Facetoface plugin..."
unzip mod_facetoface_moodle35_2018110900.zip -d ${moodleDocumentRoot}/mod

echo "Downloading Facetoface plugin zip file..."
wget https://moodle.org/plugins/download.php/20891/mod_questionnaire_moodle38_2019101705.zip
echo "Extracting Facetoface plugin..."
unzip mod_questionnaire_moodle38_2019101705.zip -d ${moodleDocumentRoot}/mod

echo "Updating file ownership on ${moodleDocumentRoot}..."
chown -R ${apache2User} ${moodleDocumentRoot}
chgrp -R root ${moodleDocumentRoot}

echo "Done."

###############################################################################
echo_title "Run Moodle Installer."
###############################################################################
sudo -u ${apache2User} /usr/bin/php ${moodleDocumentRoot}/admin/cli/install.php \
--non-interactive \
--lang=en \
--chmod=2777 \
--wwwroot=https://${moodleDnsName}/ \
--dataroot=/mnt/${fileShareName}/ \
--dbtype=pgsql \
--dbhost=${dbServerName}.postgres.database.azure.com \
--dbname=${moodleDbName} \
--prefix=mdl_ \
--dbport=5432 \
--dbuser=${moodleDbUsername}@${dbServerName} \
--dbpass="${moodleDbPassword}" \
--fullname="Moodle" \
--shortname="Moodle" \
--summary="Welcome - Bienvenue" \
--adminuser=${moodleAdminUsername} \
--adminpass="${moodleAdminPassword}" \
--adminemail=${moodleAdminEmail} \
--upgradekey=${moodleUpgradeKey} \
--agree-license

###############################################################################
echo_title "Update Moodle config for SSL Proxy and Local Cache directory."
###############################################################################
# No need to test for existing values since the file is always new.
echo "Adding SSL Proxy setting to ${moodleDocumentRoot}/config.php file..."
sed -i '/^\$CFG->wwwroot.*/a \$CFG->sslproxy\t= true;' ${moodleDocumentRoot}/config.php

echo "Adding Local Cache Directory setting to ${moodleDocumentRoot}/config.php file..."
sed -i "/^\$CFG->dataroot.*/a \$CFG->localcachedir\t= '${moodleLocalCacheRoot}';" ${moodleDocumentRoot}/config.php

echo "Adding default timezone setting to ${moodleDocumentRoot}/config.php file..."
sed -i "/^\$CFG->upgradekey.*/a date_default_timezone_set('America/Toronto');" ${moodleDocumentRoot}/config.php

echo "Done"

###############################################################################
echo_title "Update Moodle Universal Cache (MUC) config for Redis."
###############################################################################
mucConfigFile="/mnt/${fileShareName}/muc/config.php"
if ! grep -q ${redisName} ${mucConfigFile}; then
    echo "Updating ${mucConfigFile} file..."
    php ${installDir}/update_muc.php ${redisName} ${redisPassword} ${mucConfigFile}
else
    echo "Skipping ${mucConfigFile} file update."
fi
echo "Done"

###############################################################################
echo_title "Install plugins that have been recently added on the file system."
###############################################################################
sudo -u ${apache2User} /usr/bin/php ${moodleDocumentRoot}/admin/cli/upgrade.php --non-interactive
echo "Done."

###############################################################################
echo_title "Uninstall plugings that have been recently removed from the file system."
###############################################################################
sudo -u ${apache2User} /usr/bin/php ${moodleDocumentRoot}/admin/cli/uninstall_plugins.php --purge-missing --run
echo "Done."

###############################################################################
echo_title "Purge all Moodle Caches."
###############################################################################
sudo -u ${apache2User} /usr/bin/php ${moodleDocumentRoot}/admin/cli/purge_caches.php
echo "Done"

###############################################################################
echo_title "Set Moodle Crontab."
###############################################################################
crontab -l | { cat; echo "* * * * * sudo -u www-data php ${moodleDocumentRoot}/admin/cli/cron.php > /dev/null"; } | crontab -
echo "Done"

###############################################################################
echo_title "Finishing $0 on $(date)."
###############################################################################