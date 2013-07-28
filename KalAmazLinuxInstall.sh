#!/bin/bash
set -e

# KalAmazLinuxInstall.sh
#
# Install Kaltura CE4 prerequisites on 
# Amazon Linux AMI 32bit or 64 bit (CentOS compatible)

# Only root can run the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# This script only works with Amazon Linux AMIs
if [ ! -f "/etc/image-id" ]; then
   echo "This script may only be used with Amazon Linux AMIs"
   echo "http://aws.amazon.com/amazon-linux-ami"
   exit 1
fi

# Is it a 32-bit or 64-bit image?
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
tar xvfz pdi-ce-3.2.0-stable.tar.gz -C /usr/local/pentaho
rm *.gz
mv data-integration pdi

# UPDATE SYSTEM
yum -y update

# INSTALL Apache2/mysql/php
# We need gcc and devel versions for compiling extensions later

yum -y install httpd-devel
yum -y install mysql
yum -y install php-devel
yum -y install php-gd
yum -y install php-pear
yum -y install php-xsl 
yum -y install php-imap 
yum -y install php-mysql mysql-server
yum -y install make
yum -y install gcc

# ADD apache extensions

conf=/etc/httpd/conf/httpd.conf
f1="#LoadModule filter_module"
f2="LoadModule filter_module"
g1="#LoadModule file_cache_module"
g2="LoadModule file_cache_module"

sed -i "s/$f1/$f2/" $conf
sed -i "s/$g1/$g2/" $conf

# INSTALL ImageMagick

yum -y install ImageMagick

# Set default timezone and fix request order in php.ini 
# (by default, both the php apache module and CLI use /etc/php.ini)
# (http://www.php.net/manual/en/timezones.php)

f1=';date.timezone ='
f2='date.timezone = "America\/New_York"'
g1='request_order = "GP"'
g2='request_order = "CGP"'

phpini=/etc/php.ini

sed -i "s/$f1/$f2/" $phpini
sed -i "s/$g1/$g2/" $phpini

# ADD POSTFIX FOR MAIL SERVICE AND CONFIGURE FOR SENDGRID
yum -y install postfix
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

mycnf=/etc/my.cnf
f1="\[mysqld\]"
f2="\[mysqld\] \n lower_case_table_names = 1 \n thread_stack = 262144 \n open_files_limit=50000"
sed -i "s/$f1/$f2/" $mycnf

# INSTALL memcached and php memcache extension
# To get memcached on Rackspace CentOS, had to
# look here:  
# http://usmanraza.com/how-to-install-memcached-on-centos-5-6.html

yum -y install zlib-devel
yum -y install memcached
yum -y install php-pecl-memcache

# INSTALL APC
yum -y install php-pecl-apc
apccnf=/etc/php.d/apc.ini
f1="\/tmp\/apc.XXXXXX"
f2="\/dev\/zero"
sed -i "s/$f1/$f2/" $apccnf
f1="apc.ttl=7200"
f2="apc.ttl=0"
sed -i "s/$f1/$f2/" $apccnf

# START STUFF
apachectl restart
/etc/init.d/mysqld start
/etc/init.d/postfix start

# SET MYSQL ROOT PASSWORD TO ROOT
/usr/bin/mysqladmin -u root password root

# RESTART APACHE

apachectl restart

# INSTALL XYMON 

cd /tmp

if $bit64 ; then
wget http://cdnbakmi.kaltura.com/content/files/centos5.x86_64/xymon/perl-rrdtool-1.2.18-1.rhel5.x86_64.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.x86_64/xymon/lib64rrdtool2-1.2.18-1.rhel5.x86_64.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.x86_64/xymon/rrdtool-1.2.18-1.rhel5.x86_64.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.x86_64/xymon/xymon-4.2.3-1.rhel5.x86_64.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.x86_64/xymon/xymon-client-4.2.3-1.rhel5.x86_64.rpm
else
wget http://cdnbakmi.kaltura.com/content/files/centos5.i386/xymon/perl-rrdtool-1.2.18-1.rhel5.i386.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.i386/xymon/librrdtool2-1.2.18-1.rhel5.i386.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.i386/xymon/rrdtool-1.2.18-1.rhel5.i386.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.i386/xymon/xymon-4.2.3-1.rhel5.i386.rpm
wget http://cdnbakmi.kaltura.com/content/files/centos5.i386/xymon/xymon-client-4.2.3-1.rhel5.i386.rpm
fi

# [both 32 and 64 bit]
yum -y install perl-Time-HiRes

if $bit64 ; then
yum -y install openssl098e
yum -y install compat-openldap
yum -y install libart_lgpl
rpm -ivh xymon-* rrdtool-1.2.18-1.rhel5.x86_64.rpm perl-rrdtool-1.2.18-1.rhel5.x86_64.rpm lib64rrdtool2-1.2.18-1.rhel5.x86_64.rpm
else
yum -y install libcrypto.so.6
yum -y install liblber-2.3.so.0
yum -y install libart_lgpl_2.so.2
rpm -ivh xymon-* librrdtool2-1.2.18-1.rhel5.i386.rpm perl-rrdtool-1.2.18-1.rhel5.i386.rpm rrdtool-1.2.18-1.rhel5.i386.rpm
fi

hobconf=/etc/httpd/conf.d/hobbit-apache.conf
f1="# Require group admins"
f2="Allow from 127.0.0.1 \n Satisfy Any"
sed -i "s/$f1/$f2/" $hobconf

xycli=/etc/sysconfig/xymon-client
f1='HOBBITSERVERS=""'
f2='HOBBITSERVERS="localhost"'
sed -i "s/$f1/$f2/" $xycli

# Make sure they all restart on reboot

chkconfig mysqld on
chkconfig httpd on
chkconfig postfix on
chkconfig xymon on
chkconfig xymon-client on
chkconfig memcached on

# MAKE SURE EVERYTHING IS RUNNING
apachectl restart
/etc/init.d/mysqld restart
/etc/init.d/postfix start
/etc/init.d/xymon start
/etc/init.d/xymon-client start
/etc/init.d/memcached start

echo "All Done…."
exit 0

