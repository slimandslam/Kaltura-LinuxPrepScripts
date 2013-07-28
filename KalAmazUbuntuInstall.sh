#!/bin/bash
set -e

# KalAmazUbuntuInstall.sh
#
# Install Kaltura CE4 prerequisites on 
# Ubuntu Linux AMI 32bit or 64 bit 

# Only root can run the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   exit 1
fi

# This script only works with Amazon Ubuntu AMIs
os=`uname -a`
if [[ ! $os == *Ubuntu* ]]; then
   echo "This script may only be used with the official Ubuntu Linux AMIs"
   echo "http://cloud.ubuntu.com/ami/"
   exit 1
fi

# Is it a 32-bit or 64-bit image? Doesn't matter with Ubuntu.
arch=`uname -m`
if [ "$arch" != "x86_64" ]; then
   bit64=false
else
   bit64=true
fi

# INSTALL PENTAHO
# Do Pentaho first so that the OS has time to settle
# while Pentaho is downloaded

mkdir /usr/local/pentaho/
cd /usr/local/pentaho/
wget http://sourceforge.net/projects/pentaho/files/Data%20Integration/3.2.0-stable/pdi-ce-3.2.0-stable.tar.gz/download
mv download pdi-ce-3.2.0-stable.tar.gz
tar xvfz pdi-ce-3.2.0-stable.tar.gz -C /usr/local/pentaho
rm *.gz
mv data-integration pdi

# UPDATE SYSTEM
apt-get update

# INSTALL Apache2/mysql/php

apt-get -y install php5
apt-get -y install php5-dev
apt-get -y install apache2
apt-get -y install php5-cli
apt-get -y install php5-gd
apt-get -y install php-pear
apt-get -y install php5-mysql mysql-server
apt-get -y install mysql-client
apt-get -y install php5-curl
apt-get -y install php5-xsl
apt-get -y install php5-imap

# ADD apache extensions

sudo a2enmod rewrite headers expires filter deflate file_cache env proxy

# INSTALL ImageMagick

apt-get -y install imagemagick

# Set default timezone and fix request order in php.ini 
# (by default, both the php apache module and CLI use /etc/php.ini)
# (http://www.php.net/manual/en/timezones.php)

phpmod=/etc/php5/apache2/php.ini
phpcli=/etc/php5/cli/php.ini

f1=';date.timezone ='
f2='date.timezone = "America\/New_York"'
g1='request_order = "GP"'
g2='request_order = "CGP"'

phpini=/etc/php.ini

sed -i "s/$f1/$f2/" $phpcli
sed -i "s/$g1/$g2/" $phpcli
sed -i "s/$f1/$f2/" $phpmod
sed -i "s/$g1/$g2/" $phpmod

# ADD POSTFIX FOR MAIL SERVICE AND CONFIGURE FOR SENDGRID
apt-get -y install postfix
cp /etc/postfix/main.cf /etc/postfix/main.cf.OLD

cat > /etc/postfix/main.cf << EOF
smtp_sasl_auth_enable = yes 
smtp_sasl_password_maps = static:yourSendgridUsername:yourSendgridPassword 
smtp_sasl_security_options = noanonymous 
smtp_tls_security_level = may 
header_size_limit = 4096000
relayhost = [smtp.sendgrid.net]:587
EOF

# Add parameters to MySQL

mycnf=/etc/mysql/my.cnf
f1="\[mysqld\]"
f2="\[mysqld\] \n lower_case_table_names = 1 \n open_files_limit=50000 \n"
g1="192K"
g2="262144"
sed -i "s/$f1/$f2/" $mycnf
sed -i "s/$g1/$g2/" $mycnf

# INSTALL memcached and php memcache extension

apt-get -y install memcached
apt-get -y install php5-memcache

# INSTALL APC
apt-get install php-apc

# START STUFF
service apache2 restart
service mysql restart
service postfix restart

# Need command line mail 
apt-get -y install mailutils

# INSTALL XYMON 

apt-get -y install xymon

hobconf=/etc/apache2/conf.d/hobbit
f1="# Require group admins"
f2="Allow from 127.0.0.1 \n Satisfy Any"
sed -i "s/$f1/$f2/" $hobconf

# Need to manually configure this on Rackspace
xycli=/etc/default/hobbit-client
f1='HOBBITSERVERS=""'
f2='HOBBITSERVERS="localhost"'
sed -i "s/$f1/$f2/" $xycli

# MAKE SURE EVERYTHING IS RUNNING

service apache2 restart
service mysql restart
service postfix restart
service hobbit restart
service memcached restart

echo "All Done…."
exit 0

