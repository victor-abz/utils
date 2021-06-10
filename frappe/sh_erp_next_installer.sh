#!/bin/bash

#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#

##################################################################
#
# Project:      ERPnext 13 installer
# Version:      2.0.0
# Date:         2021-04-18
# Author:       Daif Alazmi <daif@daif.net>
#
##################################################################

# Default configurations
TIMEZONE='Asia/Riyadh'
FRAPPE_USR='frappe'
FRAPPE_PWD=''
SITE_URL='erpnext.daif.net'
SITE_PWD=''
MYSQL_PASS=''
FRAPPE_BRANCH='version-13'
ERPNEXT_BRANCH='version-13'

SRVR_ADDR=`curl -s -4 ifconfig.co`
SITE_ADDR=`dig +short $SITE_URL`
SERVER_OS=`/usr/bin/lsb_release -ds| awk '{print $1}'`
SERVER_VER=`/usr/bin/lsb_release -ds| awk '{print $2}' | cut -d. -f1,2`

# Exit if the current user is not root.
[[ $EUID -ne 0 ]] && echo -e "\033[0;31m \n>\n> Error: This script must be run as root! ... \n>\n\033[0m" && exit 1
# Exit if server ip is not equal site ip.
[[ $SITE_ADDR != $SRVR_ADDR ]] && echo -e "\033[0;31m \n>\n> Error: The server IP ($SRVR_ADDR) is not equal the site ($SITE_URL) IP ($SITE_ADDR)! ... \n>\n\033[0m" && exit 1
# Exit if server is not Ubuntu 20.04
[[ $SERVER_OS != 'Ubuntu' || $SERVER_VER != '20.04' ]] && echo -e "\033[0;31m \n>\n> Error: This script required Ubuntu 20.04 ... \n>\n\033[0m" && exit 1
# Exit if Frappe password is not set
[[ $FRAPPE_PWD == '' ]] && echo -e "\033[0;31m \n>\n> Error: please set FRAPPE_PWD ... \n>\n\033[0m" && exit 1
# Exit if Frappe admin password is not set
[[ $SITE_PWD == '' ]] && echo -e "\033[0;31m \n>\n> Error: please set SITE_PWD ... \n>\n\033[0m" && exit 1
# Exit if mysql password is not set
[[ $MYSQL_PASS == '' ]] && echo -e "\033[0;31m \n>\n> Error: please set MYSQL_PASS ... \n>\n\033[0m" && exit 1


##################################################################
# 1 - Updating system
##################################################################
echo -e "\033[0;33m \n>\n> Updating system packages... \n>\n\033[0m"
apt -y update
apt -y -o DPkg::options::="--force-confdef" upgrade


##################################################################
# 2 - Set timezone
##################################################################
echo -e "\033[0;33m \n>\n> Setting timezone to ${TIMEZONE}... \n>\n\033[0m"
timedatectl set-timezone ${TIMEZONE}
timedatectl


##################################################################
# 3 - Installing tools
##################################################################
echo -e "\033[0;33m \n>\n> Installing requirements... \n>\n\033[0m"
apt -y install git build-essential libffi-dev libssl-dev python3 python3-setuptools python3-dev python3-pip wkhtmltopdf supervisor
apt -y install fontconfig libxrender1 libxext6 libfreetype6 libx11-6 xfonts-75dpi xfonts-base zlib1g libfontconfig xvfb
# make alias
alias python=python3
alias pip=pip3

##################################################################
# 4 - Upgrading pip
##################################################################
echo -e "\033[0;33m \n>\n> Upgrading python packages... \n>\n\033[0m"
pip install --upgrade setuptools cryptography ansible pip


##################################################################
# 5 - Installing nodejs, redis, yarn
##################################################################
echo -e "\033[0;33m \n>\n> Installing nodejs, redis, yarn... \n>\n\033[0m"
curl --silent --location https://deb.nodesource.com/setup_12.x | bash -
apt -y install gcc g++ make nodejs redis-server
npm install -g yarn


##################################################################
# 6 - Starting redis-server
##################################################################
echo -e "\033[0;33m \n>\n> Starting redis-server... \n>\n\033[0m"
systemctl start redis-server
systemctl enable redis-server


##################################################################
# 7 - Installing nginx and MariaDB
##################################################################
echo -e "\033[0;33m \n>\n> Installing nginx and mariadb... \n>\n\033[0m"
apt -y install nginx
apt -y install mariadb-server mariadb-client libmysqlclient-dev
# change config
#sed -i 's/\[mysqld\]/[mysqld]\ninnodb-large-prefix=1/' /etc/mysql/mariadb.conf.d/50-server.cnf
#sed -i 's/\[mysqld\]/[mysqld]\ninnodb-file-per-table=1/' /etc/mysql/mariadb.conf.d/50-server.cnf
#sed -i 's/\[mysqld\]/[mysqld]\ninnodb-file-format=barracuda/' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/\[mysqld\]/[mysqld]\ncharacter-set-client-handshake = FALSE/' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/\[mysql\]/[mysql]\ndefault-character-set = utf8mb4/' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/utf8mb4_general_ci/utf8mb4_unicode_ci/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mysqld


##################################################################
# 8 - Securing database
##################################################################
echo -e "\033[0;33m \n>\n> Securing database... \n>\n\033[0m"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root';"
mysql -e "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_PASS}') WHERE User='root';"
mysql -e "FLUSH PRIVILEGES;"
echo -e "Database password = ${MYSQL_PASS} \n"


##################################################################
# 9 - Creating frappe user
##################################################################
echo -e "\033[0;33m \n>\n> Creating ${FRAPPE_USR} user... \n>\n\033[0m"
useradd -m -s /bin/bash ${FRAPPE_USR}
echo ${FRAPPE_USR}:${FRAPPE_PWD} | chpasswd
usermod -aG sudo ${FRAPPE_USR}
echo "${FRAPPE_USR} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${FRAPPE_USR}
echo -e "Done \n"


##################################################################
# 10 - Installing bench
##################################################################
echo -e "\033[0;33m \n>\n> Installing bench... \n>\n\033[0m"
pip3 install frappe-bench


##################################################################
# 11 - Installing frappe
##################################################################
echo -e "\033[0;33m \n>\n> Installing frappe... \n>\n\033[0m"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/; bench init frappe-bench --frappe-branch ${FRAPPE_BRANCH}"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench setup supervisor --yes"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench setup nginx --yes"
ln -s /home/${FRAPPE_USR}/frappe-bench/config/nginx.conf /etc/nginx/conf.d/frappe-bench.conf
ln -s /home/${FRAPPE_USR}/frappe-bench/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
# change chown supervisord
sed -i 's/chmod=0700/chown=frappe:frappe\nchmod=0700/' /etc/supervisor/supervisord.conf
supervisorctl reread
supervisorctl restart all
systemctl restart supervisor
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench restart"


##################################################################
# 15 - Enabling Site based multi-tenancy
##################################################################
echo -e "\033[0;33m \n>\n> Enabling Site based multi-tenancy... \n>\n\033[0m"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench config dns_multitenant on"
echo -e "Done \n"


##################################################################
# 16 - Downloading ERPNext
##################################################################
echo -e "\033[0;33m \n>\n> Downloading erpnext... \n>\n\033[0m"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench get-app --branch ${ERPNEXT_BRANCH} erpnext https://github.com/frappe/erpnext"


##################################################################
# 17 - Creating new site
##################################################################
echo -e "\033[0;33m \n>\n> Creating new site ${SITE_URL}... \n>\n\033[0m"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench new-site ${SITE_URL} --mariadb-root-password $MYSQL_PASS --admin-password $SITE_PWD"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench --site ${SITE_URL} install-app erpnext"
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; bench setup nginx --yes"
systemctl reload nginx 


##################################################################
# 18 - Installing lets-encrypt for the site
##################################################################
echo -e "\033[0;33m \n>\n> Installing lets-encrypt... \n>\n\033[0m"
systemctl stop nginx
apt -y install certbot
echo "" >> /etc/letsencrypt/cli.ini
echo "email=webmaster@${SITE_URL}" >> /etc/letsencrypt/cli.ini
echo "agree-tos = true" >> /etc/letsencrypt/cli.ini
echo "no-eff-email = true" >> /etc/letsencrypt/cli.ini
su ${FRAPPE_USR} -c "cd /home/${FRAPPE_USR}/frappe-bench/; (sleep 10; echo 'y'; sleep 20; echo 'y'; sleep 20; echo 'y';) | sudo bench setup lets-encrypt ${SITE_URL}"
certbot certonly --standalone -d ${SITE_URL}
systemctl start nginx
rm /etc/sudoers.d/${FRAPPE_USR}