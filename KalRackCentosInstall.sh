#!/bin/bash
set -e

# KalRackCentosInstall.sh
#
# Install Kaltura CE4 prerequisites on 
# Rackspace 64 bit CentOS 5.6
# NOTE: IF YOU ARE RUNNING CENTOS 5.5,
# YOU MUST FIRST UPGRADE YOUR INSTANCE
# TO CENTOS 5.6:
#
# prompt> yum clean all
# prompt> yum update
# prompt> reboot
# Verify that CentOS 5.6 is working:
# prompt> cat /etc/redhat-release
# CentOS release 5.6 (Final)


# Only root can run the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   exit 1
fi

# Is it a 32-bit or 64-bit image?
arch=`uname -m`
if [ "$arch" != "x86_64" ]; then
   bit64=false
else
   bit64=true
fi

# This script only works with CentOS 5.6 images
if ! cat /etc/redhat-release | grep -q '5.6'
then
   echo "You must be running CentOS 5.6"
   exit 1
fi

# We need the REMI Repos for the latest stuff
rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-4.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-5.rpm

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
# We may need gcc and devel versions for compiling extensions later

yum -y --enablerepo=remi,remi-test install mysql mysql-server --exclude='*.i386'
yum -y --enablerepo=remi install httpd php php-common
yum -y --enablerepo=remi install php-pear php-pdo php-mysql php-pgsql php-pecl-memcache php-gd php-mbstring php-mcrypt
yum -y --enablerepo=remi install php-xsl 
yum -y --enablerepo=remi install php-imap 
yum -y --enablerepo=remi install make
yum -y --enablerepo=remi install gcc

# ADD apache extension

conf=/etc/httpd/conf/httpd.conf
f1="#LoadModule asis_module modules\/mod_asis.so"
f2="LoadModule filter_module modules\/mod_filter.so"

sed -i "s/$f1/$f2/" $conf

# INSTALL ImageMagick

yum -y --enablerepo=remi install ImageMagick

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
yum -y --enablerepo=remi install cyrus-sasl-plain
yum -y --enablerepo=remi install mailx
yum -y --enablerepo=remi install postfix
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
f2="\[mysqld\] \n lower_case_table_names = 1 \n thread_stack = 262144"
sed -i "s/$f1/$f2/" $mycnf

# INSTALL memcached and php memcache extension

yum -y --enablerepo=remi install zlib-devel
yum -y --enablerepo=remi install memcached
yum -y --enablerepo=remi install php-pecl-memcache

# INSTALL APC
yum -y --enablerepo=remi install php-pecl-apc

# START STUFF
apachectl restart
/etc/init.d/mysqld start

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
yum -y --enablerepo=remi install perl-Time-HiRes

if $bit64 ; then
yum -y --enablerepo=remi install openssl098e
yum -y --enablerepo=remi install compat-openldap
yum -y --enablerepo=remi install libart_lgpl
rpm -ivh xymon-* rrdtool-1.2.18-1.rhel5.x86_64.rpm perl-rrdtool-1.2.18-1.rhel5.x86_64.rpm lib64rrdtool2-1.2.18-1.rhel5.x86_64.rpm
else
yum -y --enablerepo=remi install libcrypto.so.6
yum -y --enablerepo=remi install liblber-2.3.so.0
yum -y --enablerepo=remi install libart_lgpl_2.so.2
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

# Set Iptables to allow port 80 access
iptables -I RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
/sbin/service iptables save

# MAKE SURE EVERYTHING IS RUNNING
apachectl restart
/etc/init.d/mysqld restart
/etc/init.d/postfix start
/etc/init.d/xymon start
/etc/init.d/xymon-client start
/etc/init.d/memcached start

echo "All Done…."
exit 0

