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
echo_title 'Read input parameters.'
###############################################################################
echo 'Initializing expected parameters array...'
declare -A parameters=( [dbServerAdminPassword]= \
                        [dbServerAdminUsername]= \
                        [dbServerFqdn]= \
                        [dbServerName]= \
                        [fileShareName]= \
                        [moodleAdminEmail]= \
                        [moodleAdminPassword]= \
                        [moodleAdminUsername]= \
                        [moodleDbName]= \
                        [moodleDbPassword]= \
                        [moodleDbUsername]= \
                        [moodleFqdn]= \
                        [moodleUpgradeKey]= \
                        [redisHostName]= \
                        [redisName]= \
                        [redisPrimaryKey]= \
                        [storageAccountEndPoint]= \
                        [storageAccountKey]= \
                        [storageAccountName]= )

sortedParameterList=$(echo ${!parameters[@]} | tr " " "\n" | sort | tr "\n" " ");

echo "Mapping input parameter values and checking for extra parameters..."
for parameterKeyValuePair in "$@"
do
    key=$(echo $parameterKeyValuePair | cut -f1 -d=)
    value=$(echo $parameterKeyValuePair | cut -f2 -d=)

    ## Test if the parameter key start with "--" and if the parameter key (without the first 2 dashes) is a key in the expected parameter list.
    if [[ ${key} =~ ^--.*$ && ${parameters[${key:2}]+_} ]]; then
        parameters[${key:2}]=$value
    else
        echo "ERROR: Unexpected parameter: $key"
        extraParameterFlag=true;
    fi
done

echo "Checking for missing parameters..."
for p in $sortedParameterList; do
    if [[ -z ${parameters[$p]} ]]; then
        echo "ERROR: Missing parameter: $p."
        missingParameterFlag=true;
    fi
done

# Abort if missing or extra parameters.
if [[ -z $extraParameterFlag && -z $missingParameterFlag ]]; then
    echo "INFO: No missing or extra parameters."
else
    echo "ERROR: Execution aborted due to missing or extra parameters."
    usage="USAGE: $(basename $0)"
    for p in $sortedParameterList; do
        usage="${usage} --${p}=\$${p}"
    done
    echo "${usage}";
    exit 1;
fi

echo 'Echo parameter values for debug purposes...'
for p in $sortedParameterList; do
    echo "DEBUG: $p = \"${parameters[$p]}\""
done
echo "Done."


# ###############################################################################
# echo_title "Map input parameters."
# ###############################################################################
# ##
# storageAccountEndPoint="$1"
# storageAccountName="$2"
# storageAccountKey="$3"
# fileShareName="$4"
# dbServerName="$5"
# dbServerAdminUsername="$6"
# dbServerAdminPassword="$7"
# moodleDbName="$8"
# moodleDbUsername="$9"
# shift 9
# moodleDbPassword="$1"
# moodleFqdn="$2"
# moodleAdminUsername="$3"
# moodleAdminPassword="$4"
# moodleAdminEmail="$5"
# redisName="$6"
# redisPrimaryKey="$7"
# moodleUpgradeKey="$8"
# echo "Done."

# ###############################################################################
# echo_title "Echo parameter values for debuging purpose."
# ###############################################################################
# echo "storageAccountEndPoint=${parameters[storageAccountEndPoint]}"
# echo "storageAccountName=${parameters[storageAccountName]}"
# echo "storageAccountKey=${parameters[storageAccountKey]}"
# echo "fileShareName=${parameters[fileShareName]}"
# echo "dbServerName=${parameters[dbServerName]}"
# echo "dbServerAdminUsername=${parameters[dbServerAdminUsername]}"
# echo "dbServerAdminPassword=${parameters[dbServerAdminPassword]}"
# echo "moodleDbName=${parameters[moodleDbName]}"
# echo "moodleDbUsername=${parameters[moodleDbUsername]}"
# echo "moodleDbPassword=${parameters[moodleDbPassword]}"
# echo "moodleFqdn=${moodleFqdn}"
# echo "moodleAdminUsername=${parameters[moodleAdminUsername]}"
# echo "moodleAdminPassword=${parameters[moodleAdminPassword]}"
# echo "moodleAdminEmail=${parameters[moodleAdminEmail]}"
# echo "redisName=${parameters[redisName]}"
# echo "redisPrimaryKey=${parameters[redisPrimaryKey]}"
# echo "moodleUpgradeKey=${parameters[moodleUpgradeKey]}"
# echo "Done."

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
echo "Creating and granting privileges to database user ${parameters[moodleDbUsername]}..."
psql "host=${parameters[dbServerFqdn]} port=5432 dbname=postgres user=${parameters[dbServerAdminUsername]}@${parameters[dbServerName]} password=${parameters[dbServerAdminPassword]} sslmode=require" << EOF
DO \$\$
BEGIN
    IF NOT EXISTS ( SELECT FROM pg_catalog.pg_roles WHERE rolname='${parameters[moodleDbUsername]}' ) THEN
        create user ${parameters[moodleDbUsername]} with encrypted password '${parameters[moodleDbPassword]}';
        grant all privileges on database ${parameters[moodleDbName]} to ${parameters[moodleDbUsername]};
        RAISE NOTICE 'User ${parameters[moodleDbUsername]} created.';
    ELSE
      RAISE WARNING 'The user ${parameters[moodleDbUsername]} was already existing.';
    END IF;
END
\$\$;
EOF
echo "Done."

###############################################################################
echo_title "Mount Moodle data fileshare."
###############################################################################
if [ ! -d "/mnt/${parameters[fileShareName]}" ]; then
    echo "Creating /mnt/${parameters[fileShareName]} folder..."
    mkdir /mnt/${parameters[fileShareName]}
    chown -R ${apache2User} /mnt/${parameters[fileShareName]}
else
    echo "Skipping /mnt/${parameters[fileShareName]} creation."
fi
if [ ! -d "/etc/smbcredentials" ]; then
    echo "Creating /etc/smbcredentials folder..."
    mkdir /etc/smbcredentials
else
    echo "Skipping /etc/smbcredentials file creation."
fi
if [ ! -f "/etc/smbcredentials/openlearningmoodlesa.cred" ]; then
    echo "Creating /etc/smbcredentials/openlearningmoodlesa.cred file..."
    echo "username=${parameters[storageAccountName]}" >> /etc/smbcredentials/${parameters[storageAccountName]}.cred
    echo "password=${parameters[storageAccountKey]}" >> /etc/smbcredentials/${parameters[storageAccountName]}.cred
else
    echo "Skipping /etc/smbcredentials/openlearningmoodlesa.cred file creation."
fi
echo "Updating permission on /etc/smbcredentials/${parameters[storageAccountName]}.cred..."
chmod 600 /etc/smbcredentials/${parameters[storageAccountName]}.cred
if ! grep -q ${parameters[storageAccountName]} /etc/fstab; then
    echo "Updating /etc/fstab file..."
    echo "//$(echo ${parameters[storageAccountEndPoint]} | awk -F/ '{print $3}')/${parameters[fileShareName]} /mnt/${parameters[fileShareName]} cifs nofail,vers=3.0,credentials=/etc/smbcredentials/${parameters[storageAccountName]}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
else
    echo "Skipping /etc/fstab file update."
fi
echo "Mounting all defined mount points..."
mount -a
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
tar zxfv moodle-latest-38.tgz -C ${defaultDocumentRoot}

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

echo "Downloading Activities: Questionnaire plugin zip file..."
wget https://moodle.org/plugins/download.php/20891/mod_questionnaire_moodle38_2019101705.zip
echo "Extracting Activities: Questionnaire plugin..."
unzip mod_questionnaire_moodle38_2019101705.zip -d ${moodleDocumentRoot}/mod

echo "Downloading Themes: Boost Campus zip file..."
wget https://moodle.org/plugins/download.php/21242/theme_boost_campus_moodle38_2020032400.zip
echo "Extracting Themes: Boost Campus plugin..."
unzip theme_boost_campus_moodle38_2020032400.zip -d ${moodleDocumentRoot}/theme

echo "Downloading Local Static Pages plugin zip file..."
wget https://moodle.org/plugins/download.php/21045/local_staticpage_moodle38_2020021400.zip
echo "Extracting Local Static Pages plugin..."
unzip local_staticpage_moodle38_2020021400.zip -d ${moodleDocumentRoot}/local

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
--wwwroot=https://${parameters[moodleFqdn]}/ \
--dataroot=/mnt/${parameters[fileShareName]}/ \
--dbtype=pgsql \
--dbhost=${parameters[dbServerFqdn]} \
--dbname=${parameters[moodleDbName]} \
--prefix=mdl_ \
--dbport=5432 \
--dbuser=${parameters[moodleDbUsername]}@${parameters[dbServerName]} \
--dbpass="${parameters[moodleDbPassword]}" \
--fullname="Moodle" \
--shortname="Moodle" \
--summary="Welcome - Bienvenue" \
--adminuser=${parameters[moodleAdminUsername]} \
--adminpass="${parameters[moodleAdminPassword]}" \
--adminemail=${parameters[moodleAdminEmail]} \
--upgradekey=${parameters[moodleUpgradeKey]} \
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
mucConfigFile="/mnt/${parameters[fileShareName]}/muc/config.php"
if ! grep -q ${parameters[redisName]} ${mucConfigFile}; then
    echo "Updating ${mucConfigFile} file..."
    echo "************************************* Content of ${mucConfigFile} BEFORE the update *************************************"
    cat ${mucConfigFile}
    echo "********************************** Content of ${mucConfigFile} BEFORE the update (EOF) **********************************"
    php ${installDir}/update_muc.php ${parameters[redisHostName]} ${parameters[redisName]} ${parameters[redisPrimaryKey]} ${mucConfigFile}
    echo "************************************* Content of ${mucConfigFile} AFTER the update **************************************"
    cat ${mucConfigFile}
    echo "********************************** Content of ${mucConfigFile} AFTER the update (EOF) ***********************************"
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