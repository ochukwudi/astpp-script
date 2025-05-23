#!/bin/bash
###############################################################################
# ASTPP - Open Source VoIP Billing Solution
#
# Copyright (C) 2019 iNextrix Technologies Pvt. Ltd.
# ASTPP Version 3.5
# License https://www.gnu.org/licenses/agpl-3.0.html
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################


#################################
##########  variables ###########
#################################

#General Congifuration
TEMP_USER_ANSWER="no"
ASTPP_SOURCE_DIR=/opt/ASTPP
ASTPP_HOST_DOMAIN_NAME="host.domain.tld"
IS_ENTERPRISE="False"

#ASTPP Configuration
ASTPPDIR=/var/lib/astpp/
ASTPPEXECDIR=/usr/local/astpp/
ASTPPLOGDIR=/var/log/astpp/

#Freeswich Configuration
FS_DIR=/usr/share/freeswitch
FS_SOUNDSDIR=${FS_DIR}/sounds/en/us/callie

#HTML and Mysql Configuraition
WWWDIR=/var/www/html
ASTPP_DATABASE_NAME="astpp"
ASTPP_DB_USER="astppuser"

#################################
####  general functions #########
#################################

#Generate random password
genpasswd() 
{
        length=$1
        digits=({1..9})
        lower=({a..z})
        upper=({A..Z})
        CharArray=(${digits[*]} ${lower[*]} ${upper[*]})
        ArrayLength=${#CharArray[*]}
        password=""
        for i in `seq 1 $length`
        do
                index=$(($RANDOM%$ArrayLength))
                char=${CharArray[$index]}
                password=${password}${char}
        done
        echo $password
}

MYSQL_ROOT_PASSWORD=`echo "$(genpasswd 20)" | sed s/./*/5`
ASTPPUSER_MYSQL_PASSWORD=`echo "$(genpasswd 20)" | sed s/./*/5`
#Fetch OS Distribution
get_linux_distribution ()
{
        echo -e "$Cyan ===get_linux_distribution===$Color_Off"
        sleep 2s
        V1=`cat /etc/*release | head -n1 | tail -n1 | cut -c 14- | cut -c1-18`
        V2=`cat /etc/*release | head -n7 | tail -n1 | cut -c 14- | cut -c1-14`
        V3=`cat /etc/*release | grep Deb | head -n1 | tail -n1 | cut -c 14- | cut -c1-19`
        V4=`cat /etc/*release | grep Deb | head -n1 | tail -n1 | cut -c 14- | cut -c1-19`
        if [[ $V1 = "Debian GNU/Linux 9" ]]; then
                DIST="DEBIAN"
                echo -e "$Green ===Your OS is $V1===$Color_Off"
        else if [[ $V2 = "CentOS Linux 7" ]]; then
                DIST="CENTOS"
                echo -e "$Green ===Your OS is $V2===$Color_Off"
        else if [[ $V3 = "Debian GNU/Linux 10" || $V4 = "Debian GNU/Linux 11" ]]; then
                DIST="DEBIAN10"
                echo -e "$Green ===Your OS is $V3===$Color_Off"
        else if [[$V4 = "Debian GNU/Linux 11"]]; then
                echo -e "$Green ===Your OS is $V4===$Color_Off"
        else
                DIST="OTHER"
                echo -e 'Ooops!!! Quick Installation does not support your distribution \nPlease use manual steps or contact ASTPP Sales Team \nat sales@astppbilling.org.'
                exit 1
                
                
        fi
        fi
        fi
        fi
        #echo -e "$Green ===Your OS is $DIST===$Color_Off"
        sleep 4s
}


#Verify freeswitch token
verification ()
{
        tput bold
        echo "                       Authentication required !!!!!!
Personal Access Tokens (PAT)s are required to access FreeSWITCH install packages."
        echo ""

        echo "VISIT below link to generate Personal Access Token
https://freeswitch.org/confluence/display/FREESWITCH/HOWTO+Create+a+SignalWire+Personal+Access+Token"
        sleep 3s
        echo "" && echo ""
        read -p "Enter your Personal Access Token: ${FS_TOKEN}"
        tput sgr0
        FS_TOKEN=${REPLY}
        echo ""
        if [ $DIST = "DEBIAN10" ]; then
                wget --http-user=signalwire --http-password=$FS_TOKEN -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg
                verify_debian10="$?"
                if [ $verify_debian10 = 0 ]; then
                        tput bold
                        echo "******************************************************************************"
                        echo ""
                        echo "You have entered valid token"
                        echo ""
                        echo "******************************************************************************"
                        sleep 4s
                        tput sgr0
                else
                        echo ""
                        tput bold
                        echo "Invalid token"
                        echo "******************************************************************************"
                        echo ""
                        echo "For more information go to https://id.signalwire.com/personal_access_tokens "
                        echo ""
                        echo "******************************************************************************"
                        sleep 3s
                        tput sgr0
                        exit 0
                fi
        elif [ $DIST = "CENTOS" ]; then
                yum -y remove freeswitch-release-repo.noarch
                echo "signalwire" > /etc/yum/vars/signalwireusername
                echo "$FS_TOKEN" > /etc/yum/vars/signalwiretoken
                yum install -y https://$(< /etc/yum/vars/signalwireusername):$(< /etc/yum/vars/signalwiretoken)@freeswitch.signalwire.com/repo/yum/centos-release/freeswitch-release-repo-0-1.noarch.rpm 
                verify_centos="$?"
                if [ $verify_centos = 0 ]; then
                        tput bold
                        echo "******************************************************************************"
                        echo ""
                        echo "You have entered valid token"
                        echo ""
                        echo "******************************************************************************"
                        sleep 4s
                        tput sgr0
                else
                        echo ""
                        tput bold
                        echo "Invalid token"
                        echo "******************************************************************************"
                        echo ""
                        echo "For more information go to https://id.signalwire.com/personal_access_tokens "
                        echo ""
                        echo "******************************************************************************"
                        sleep 3s
                        tput sgr0
                        exit 0
                fi
        fi
}
#Install Prerequisties
install_prerequisties ()
{
        if [ $DIST = "CENTOS" ]; then
                systemctl stop httpd
                systemctl disable httpd
                yum update -y
                yum install -y wget curl git bind-utils ntpdate systemd net-tools whois sendmail sendmail-cf mlocate vim
        else if [ $DIST = "DEBIAN" ]; then
                systemctl stop apache2
                systemctl disable apache2
                apt update
                apt install -y sudo wget curl git dnsutils ntpdate systemd net-tools whois sendmail-bin sensible-mda mlocate vim
        else if [ $DIST = "DEBIAN10" ]; then
		apt install -y sudo
                sudo apt-get update
                sudo apt-get install -y wget curl git dnsutils ntpdate systemd net-tools whois sendmail-bin sensible-mda mlocate vim imagemagick
        fi
        fi
        fi
        cd /usr/src/
        wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
        tar -xzvf ioncube_loaders_lin_x86-64.tar.gz
        cd ioncube
}

#Fetch ASTPP Source
get_astpp_source ()
{
        cd /opt
        git clone -b V6.0 https://github.com/iNextrix/ASTPP/
	
}

#License Acceptence
license_accept ()
{
        cd /usr/src
        if [ $IS_ENTERPRISE = "True" ]; then
                echo ""
        fi
        if [ $IS_ENTERPRISE = "False" ]; then
                clear
                echo "********************"
                echo "License acceptance"
                echo "********************"
                if [ -f LICENSE ]; then
                        more LICENSE
                else
                        wget --no-check-certificate -q -O GNU-AGPLv5.0.txt https://raw.githubusercontent.com/iNextrix/ASTPP/master/LICENSE
                        more GNU-AGPLv5.0.txt
                fi
                echo "***"
                echo "*** I agree to be bound by the terms of the license - [YES/NO]"
                echo "*** " 
                read ACCEPT
                while [ "$ACCEPT" != "yes" ] && [ "$ACCEPT" != "Yes" ] && [ "$ACCEPT" != "YES" ] && [ "$ACCEPT" != "no" ] && [ "$ACCEPT" != "No" ] && [ "$ACCEPT" != "NO" ]; do
                        echo "I agree to be bound by the terms of the license - [YES/NO]"
                        read ACCEPT
                done
                if [ "$ACCEPT" != "yes" ] && [ "$ACCEPT" != "Yes" ] && [ "$ACCEPT" != "YES" ]; then
                        echo "Ooops!!! License rejected!"
                        LICENSE_VALID=False
                        exit 0
                else
                        echo "Hey!!! Licence accepted!"
                        LICENSE_VALID=True
                fi
        fi
}

#Install PHP
install_php ()
{
        cd /usr/src
        if [ "$DIST" = "DEBIAN" ]; then
                apt -y install lsb-release apt-transport-https ca-certificates 
                wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.4.list
                apt-get update
                apt install -y php7.4 php7.4-fpm php7.4-mysql php7.4-cli php7.4-json php7.4-readline php7.4-xml php7.4-curl php7.4-gd php7.4-json php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-imap
                apt purge php8.*
                systemctl stop apache2
                systemctl disable apache2
        else if [ "$DIST" = "CENTOS" ]; then
                yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm 
                yum -y install epel-release yum-utils
                yum-config-manager --disable remi-php54
                yum-config-manager --enable remi-php74
                yum install -y php php-fpm php-mysql php-cli php-json php-readline php-xml php-curl php-gd php-json php-mbstring php-opcache php-imap php-pear php-geoip php-imagick libreoffice ghostscript
                systemctl stop httpd
                systemctl disable httpd
        else if [ "$DIST" = "DEBIAN10" ]; then
                apt -y install lsb-release apt-transport-https ca-certificates
                wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.4.list
                apt-get update
                apt install -y php7.4 php7.4-fpm php7.4-mysql php7.4-cli php7.4-json php7.4-readline php7.4-xml php7.4-curl php7.4-gd php7.4-json php7.4-mbstring php7.4-opcache php7.4-imap php7.4-geoip php-pear php-imagick libreoffice ghostscript
                apt purge php8.*
                systemctl stop apache2
                systemctl disable apache2
        fi
        fi
        fi 
}

#Install Mysql
install_mysql ()
{
        cd /usr/src
        if [ "$DIST" = "DEBIAN" ]; then
                sudo apt install dirmngr --install-recommends
                sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C
                wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
                sudo dpkg --install mysql-apt-config_0.8.24-1_all.deb
		#wget https://repo.mysql.com//mysql-apt-config_0.8.22-1_all.deb
		#sudo dpkg --install mysql-apt-config_0.8.22-1_all.deb                
		apt update
                apt -y install unixodbc unixodbc-bin
                debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)"
                DEBIAN_FRONTEND=noninteractive apt install mysql-server
                cd /opt/ASTPP/misc/
                tar -xzvf odbc.tar.gz
                cp -rf odbc/libmyodbc8* /usr/lib/x86_64-linux-gnu/odbc/.

        else if [ "$DIST" = "CENTOS" ]; then
                wget https://repo.mysql.com/mysql80-community-release-el7-1.noarch.rpm
                rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
                yum localinstall -y mysql80-community-release-el7-1.noarch.rpm
                yum install -y mysql-community-server unixODBC mysql-connector-odbc
                systemctl start mysqld
                MYSQL_ROOT_TEMP=$(grep 'temporary password' /var/log/mysqld.log | cut -c 14- | cut -c100-111 2>&1)
                mysql -uroot -p${MYSQL_ROOT_TEMP} --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';FLUSH PRIVILEGES;"
        else if [ "$DIST" = "DEBIAN10" ]; then
                apt install gnupg -y
                sudo apt install dirmngr --install-recommends
                apt-get install software-properties-common -y
                sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C
                wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
                sudo dpkg --install mysql-apt-config_0.8.24-1_all.deb
		#wget https://repo.mysql.com//mysql-apt-config_0.8.22-1_all.deb
		#sudo dpkg --install mysql-apt-config_0.8.22-1_all.deb
                apt update -y
                #apt -y install unixodbc unixodbc-bin
		apt-get install unixodbc unixodbc-dev
                debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}"
                debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)"
                DEBIAN_FRONTEND=noninteractive apt install mysql-server
                cd /opt/ASTPP/misc/
                tar -xzvf odbc.tar.gz
		mkdir -p /usr/lib/x86_64-linux-gnu/odbc/.
                cp -rf odbc/libmyodbc8* /usr/lib/x86_64-linux-gnu/odbc/.
	
        fi
        fi
	fi
        echo ""
        echo "MySQL password set to '${MYSQL_ROOT_PASSWORD}'. Remember to delete ~/.mysql_passwd" >> ~/.mysql_passwd
        echo "" >>  ~/.mysql_passwd
        echo "MySQL astppuser password:  ${ASTPPUSER_MYSQL_PASSWORD} " >>  ~/.mysql_passwd
        chmod 400 ~/.mysql_passwd	
}

#Normalize mysql installation
normalize_mysql ()
{
        if [ ${DIST} = "DEBIAN" ]; then
                cp ${ASTPP_SOURCE_DIR}/misc/odbc/deb_odbc.ini /etc/odbc.ini
                sed -i '33i wait_timeout=600' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i interactive_timeout = 600' /etc/mysql/mysql.conf.d/mysqld.cnf
                sed -i '33i sql_mode=""' /etc/mysql/mysql.conf.d/mysqld.cnf
                systemctl restart mysql
                systemctl enable mysql
        elif  [ ${DIST} = "CENTOS" ]; then
                systemctl start mysqld
                systemctl enable mysqld
                cp ${ASTPP_SOURCE_DIR}/misc/odbc/cent_odbc.ini /etc/odbc.ini
                sed -i '26i wait_timeout=600' /etc/my.cnf
                sed -i '26i interactive_timeout = 600' /etc/my.cnf
                sed -i '26i sql-mode=""' /etc/my.cnf
                systemctl restart mysqld
                systemctl enable mysqld
        elif  [ ${DIST} = "DEBIAN10" ]; then
                cp ${ASTPP_SOURCE_DIR}/misc/odbc/deb_odbc.ini /etc/odbc.ini
                               
                sed -i '28i wait_timeout=600' /etc/mysql/conf.d/mysql.cnf
                sed -i '28i interactive_timeout = 600' /etc/mysql/conf.d/mysql.cnf
                sed -i '28i sql_mode=""' /etc/mysql/conf.d/mysql.cnf
		sed -i '33i log_bin_trust_function_creators = 1' /etc/mysql/conf.d/mysql.cnf
                sed -i '28i [mysqld]' /etc/mysql/conf.d/mysql.cnf
                systemctl restart mysql
                systemctl enable mysql
        fi
}

#User Response Gathering
get_user_response ()
{
        echo ""
        read -p "Enter FQDN example (i.e ${ASTPP_HOST_DOMAIN_NAME}): "
        ASTPP_HOST_DOMAIN_NAME=${REPLY}
        echo "Your entered FQDN is : ${ASTPP_HOST_DOMAIN_NAME} "
        echo ""
        # read -p "Enter your freeswitch token: ${FS_TOKEN}"
        # FS_TOKEN=${REPLY}
        # echo ""
        read -p "Enter your email address: ${EMAIL}"
        EMAIL=${REPLY}
        echo ""
        read -n 1 -p "Press any key to continue ... "
        NAT1=$(dig +short myip.opendns.com @resolver1.opendns.com)
        NAT2=$(curl http://ip-api.com/json/)
        INTF=$(ifconfig $1|sed -n 2p|awk '{ print $2 }'|awk -F : '{ print $2 }')
        if [ "${NAT1}" != "${INTF}" ]; then
                echo "Server is behind NAT";
                NAT="True"
        fi
        curl --data "email=$EMAIL" --data "data=$NAT2" --data "type=Install" https://astppbilling.org/lib/
}

#Install ASTPP with dependencies
install_astpp ()
{
        if [[ ${DIST} = "DEBIAN" || ${DIST} = "DEBIAN10" || ${DIST} = "DEBIAN11" ]]; then
                echo "Installing dependencies for ASTPP"
                apt update
                apt install -y nginx ntpdate ntp lua5.1 bc libxml2 libxml2-dev openssl libcurl4-openssl-dev gettext gcc g++
                echo "Installing dependencies for ASTPP"
        elif  [ ${DIST} = "CENTOS" ]; then
                echo "Installing dependencies for ASTPP"
                yum install -y nginx libxml2 libxml2-devel openssl openssl-devel gettext-devel fileutils gcc-c++
        fi
        echo "Creating neccessary locations and configuration files ..."
        mkdir -p ${ASTPPDIR}
        mkdir -p ${ASTPPLOGDIR}
        mkdir -p ${ASTPPEXECDIR}
        mkdir -p ${WWWDIR}
        cp -rf ${ASTPP_SOURCE_DIR}/config/astpp-config.conf ${ASTPPDIR}astpp-config.conf
        cp -rf ${ASTPP_SOURCE_DIR}/config/astpp.lua ${ASTPPDIR}astpp.lua
        ln -s ${ASTPP_SOURCE_DIR}/web_interface/astpp ${WWWDIR}
        ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
}

#Normalize astpp installation
normalize_astpp ()
{
	sudo apt-get install -y locales-all
        mkdir -p /etc/nginx/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
        if [ ${DIST} = "DEBIAN" ]; then
                /bin/cp /usr/src/ioncube/ioncube_loader_lin_7.4.so /usr/lib/php/20180731/
                sed -i '2i zend_extension ="/usr/lib/php/20190902/ioncube_loader_lin_7.4.so"' /etc/php/7.4/fpm/php.ini
                sed -i '2i zend_extension ="/usr/lib/php/20190902/ioncube_loader_lin_7.4.so"' /etc/php/7.4/cli/php.ini
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_astpp.conf /etc/nginx/conf.d/astpp.conf
                systemctl start nginx
                systemctl enable nginx
                systemctl start php7.4-fpm
                systemctl enable php7.4-fpm
                chown -Rf root.root ${ASTPPDIR}	
                chown -Rf www-data.www-data ${ASTPPLOGDIR}
                chown -Rf root.root ${ASTPPEXECDIR}
                chown -Rf www-data.www-data ${WWWDIR}/astpp
                chown -Rf www-data.www-data ${ASTPP_SOURCE_DIR}/web_interface/astpp
                chmod -Rf 755 ${WWWDIR}/astpp     
                sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php/7.4/fpm/pool.d/www.conf
                sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php/7.4/fpm/php.ini
                sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php/7.4/fpm/php.ini
                sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php/7.4/fpm/php.ini
                sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php/7.4/fpm/php.ini
                sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php/7.4/fpm/php.ini
                sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.4/fpm/php.ini
                systemctl restart php7.4-fpm
                CRONPATH='/var/spool/cron/crontabs/astpp'
        elif  [ ${DIST} = "CENTOS" ]; then
                #cp /usr/src/ioncube/ioncube_loader_lin_7.3.so /usr/lib64/php/modules/
                #sed -i '2i zend_extension ="/usr/lib64/php/modules/ioncube_loader_lin_7.3.so"' /etc/php.ini
                cp ${ASTPP_SOURCE_DIR}/web_interface/nginx/cent_astpp.conf /etc/nginx/conf.d/astpp.conf
                setenforce 0
                systemctl start nginx
                systemctl enable nginx
                systemctl start php-fpm
                systemctl enable php-fpm
                chown -Rf root.root ${ASTPPDIR}
                chown -Rf apache.apache ${ASTPPLOGDIR}
                chown -Rf root.root ${ASTPPEXECDIR}
                chown -Rf apache.apache ${WWWDIR}/astpp
                chown -Rf apache.apache ${ASTPP_SOURCE_DIR}/web_interface/astpp
                chmod -Rf 755 ${WWWDIR}/astpp
                sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php-fpm.d/www.conf
                sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php.ini
                sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php.ini
                sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php.ini
                sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php.ini
                sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php.ini
                sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php.ini
                systemctl restart php-fpm
                CRONPATH='/var/spool/cron/astpp'
        elif  [ ${DIST} = "DEBIAN10" ]; then
		sudo apt-get install -y locales-all
                /bin/cp /usr/src/ioncube/ioncube_loader_lin_7.4.so /usr/lib/php/20190902/
                sed -i '2i zend_extension ="/usr/lib/php/20190902/ioncube_loader_lin_7.4.so"' /etc/php/7.4/fpm/php.ini
                sed -i '2i zend_extension ="/usr/lib/php/20190902/ioncube_loader_lin_7.4.so"' /etc/php/7.4/cli/php.ini
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_astpp.conf /etc/nginx/conf.d/astpp.conf
                systemctl start nginx
                systemctl enable nginx
                systemctl start php7.4-fpm
                systemctl enable php7.4-fpm
                chown -Rf root.root ${ASTPPDIR}
                chown -Rf www-data.www-data ${ASTPPLOGDIR}
                chown -Rf root.root ${ASTPPEXECDIR}
                chown -Rf www-data.www-data ${WWWDIR}/astpp
                chown -Rf www-data.www-data ${ASTPP_SOURCE_DIR}/web_interface/astpp
                chmod -Rf 755 ${WWWDIR}/astpp
                sed -i "s/;request_terminate_timeout = 0/request_terminate_timeout = 300/" /etc/php/7.4/fpm/pool.d/www.conf
                sed -i "s#short_open_tag = Off#short_open_tag = On#g" /etc/php/7.4/fpm/php.ini
                sed -i "s#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=1#g" /etc/php/7.4/fpm/php.ini
                sed -i "s/max_execution_time = 30/max_execution_time = 3000/" /etc/php/7.4/fpm/php.ini
                sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php/7.4/fpm/php.ini
                sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php/7.4/fpm/php.ini
                sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.4/fpm/php.ini
                systemctl restart php7.4-fpm
                CRONPATH='/var/spool/cron/crontabs/astpp'
        fi
        echo "# To call all crons   
                * * * * * cd ${ASTPP_SOURCE_DIR}/web_interface/astpp/cron/ && php cron.php crons
                " > $CRONPATH
                chmod 600 $CRONPATH
                crontab $CRONPATH
        touch /var/log/astpp/astpp.log
        touch /var/log/astpp/astpp_email.log
        chmod -Rf 755 $ASTPP_SOURCE_DIR
	chmod -Rf 777 /opt/ASTPP/
	chmod -Rf 777 /opt/ASTPP/*
	chmod -Rf 777 /opt/ASTPP
        chmod 777 /var/log/astpp/astpp.log
        chmod 777 /var/log/astpp/astpp_email.log
        sed -i "s#dbpass = <PASSSWORD>#dbpass = ${ASTPPUSER_MYSQL_PASSWORD}#g" ${ASTPPDIR}astpp-config.conf
        sed -i "s#DB_PASSWD=\"<PASSSWORD>\"#DB_PASSWD = \"${ASTPPUSER_MYSQL_PASSWORD}\"#g" ${ASTPPDIR}astpp.lua
        sed -i "s#base_url=https://localhost:443/#base_url=https://${ASTPP_HOST_DOMAIN_NAME}/#g" ${ASTPPDIR}/astpp-config.conf
        sed -i "s#PASSWORD = <PASSWORD>#PASSWORD = ${ASTPPUSER_MYSQL_PASSWORD}#g" /etc/odbc.ini
        systemctl restart nginx
}

#Install freeswitch with dependencies
install_freeswitch ()
{

        if [ ${DIST} = "DEBIAN" ]; then
                clear
                echo "Installing FREESWITCH"
                sleep 5
                apt-get install -y gnupg2
                echo "machine freeswitch.signalwire.com login signalwire password $FS_TOKEN" > /etc/apt/auth.conf
                echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list
                echo "deb-src [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list
                apt-get update -y
                sleep 1s
                apt-get install freeswitch-meta-all -y
                
        elif  [ ${DIST} = "CENTOS" ]; then
                clear
                sleep 5
                echo "Installing FREESWITCH"
                yum install -y epel-release
                yum install -y freeswitch-config-vanilla freeswitch-lang-* freeswitch-sounds-* freeswitch-xml-curl freeswitch-event-json-cdr freeswitch-lua
                apt-get update && apt-get install -y freeswitch-meta-all
                echo "FREESWITCH installed successfully. . ."

        elif  [ ${DIST} = "DEBIAN10" ]; then
                echo "Installing FREESWITCH"
                sleep 6s
                apt-get update && apt-get install -y gnupg2 wget lsb-release
                echo "machine freeswitch.signalwire.com login signalwire password $FS_TOKEN" > /etc/apt/auth.conf
                echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list
                echo "deb-src [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list
                apt-get update -y
                sleep 2s
                apt-get install freeswitch-meta-all -y
                
        fi
        mv -f ${FS_DIR}/scripts /tmp/.
        ln -s ${ASTPP_SOURCE_DIR}/freeswitch/fs ${WWWDIR}
        ln -s ${ASTPP_SOURCE_DIR}/freeswitch/scripts ${FS_DIR}
        cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/sounds/*.wav ${FS_SOUNDSDIR}/
        cp -rf ${ASTPP_SOURCE_DIR}/freeswitch/conf/autoload_configs/* /etc/freeswitch/autoload_configs/
}

#Normalize freeswitch installation
normalize_freeswitch ()
{
        systemctl start freeswitch
        systemctl enable freeswitch
        sed -i "s#max-sessions\" value=\"1000#max-sessions\" value=\"2000#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#sessions-per-second\" value=\"30#sessions-per-second\" value=\"50#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#max-db-handles\" value=\"50#max-db-handles\" value=\"500#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        sed -i "s#db-handle-timeout\" value=\"10#db-handle-timeout\" value=\"30#g" /etc/freeswitch/autoload_configs/switch.conf.xml
        rm -rf  /etc/freeswitch/dialplan/*
        touch /etc/freeswitch/dialplan/astpp.xml
        rm -rf  /etc/freeswitch/directory/*
        touch /etc/freeswitch/directory/astpp.xml
        rm -rf  /etc/freeswitch/sip_profiles/*
        touch /etc/freeswitch/sip_profiles/astpp.xml
        chmod -Rf 755 ${FS_SOUNDSDIR}
	chmod -Rf 777 /opt/ASTPP/
        chmod -Rf 777 /usr/share/freeswitch/scripts/astpp/lib
	chmod -Rf 777 /var/lib/freeswitch/recordings
	chmod -Rf 777 /var/lib/freeswitch/recordings/*
        if [ ${DIST} = "DEBIAN" ]; then
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_fs.conf /etc/nginx/conf.d/fs.conf
                chown -Rf root.root ${WWWDIR}/fs
                chmod -Rf 755 ${WWWDIR}/fs
                /bin/systemctl restart freeswitch
                /bin/systemctl enable freeswitch
        elif  [ ${DIST} = "DEBIAN10" ]; then
                cp -rf ${ASTPP_SOURCE_DIR}/web_interface/nginx/deb_fs.conf /etc/nginx/conf.d/fs.conf
                chown -Rf root.root ${WWWDIR}/fs
                chmod -Rf 755 ${WWWDIR}/fs
                /bin/systemctl restart freeswitch
                /bin/systemctl enable freeswitch
        elif  [ ${DIST} = "CENTOS" ]; then
                cp ${ASTPP_SOURCE_DIR}/web_interface/nginx/cent_fs.conf /etc/nginx/conf.d/fs.conf
                chown -Rf root.root ${WWWDIR}/fs
                chmod -Rf 755 ${WWWDIR}/fs
                sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
                sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
                /usr/bin/systemctl restart freeswitch
                /usr/bin/systemctl enable freeswitch
        fi
}

#Install Database for ASTPP
install_database ()
{
        mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} create ${ASTPP_DATABASE_NAME}
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER 'astppuser'@'localhost' IDENTIFIED BY '${ASTPPUSER_MYSQL_PASSWORD}';"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "ALTER USER 'astppuser'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ASTPPUSER_MYSQL_PASSWORD}';"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON \`${ASTPP_DATABASE_NAME}\` . * TO 'astppuser'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-6.0.sql
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} astpp < ${ASTPP_SOURCE_DIR}/database/astpp-6.0.1.sql
}

#Firewall Configuration
configure_firewall ()
{
        if [ ${DIST} = "DEBIAN" ]; then
                apt install -y firewalld
                systemctl start firewalld
                systemctl enable firewalld
                firewall-cmd --permanent --zone=public --add-service=https
                                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-port=5060/udp
                                firewall-cmd --permanent --zone=public --add-port=5060/tcp
                firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
                firewall-cmd --reload
        elif  [ ${DIST} = "DEBIAN10" ]; then
                                apt install -y firewalld
                systemctl start firewalld
                systemctl enable firewalld
                firewall-cmd --permanent --zone=public --add-service=https
                                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-port=5060/udp
                                firewall-cmd --permanent --zone=public --add-port=5060/tcp
                firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
                firewall-cmd --reload
        elif  [ ${DIST} = "CENTOS" ]; then
                yum install -y firewalld
                systemctl start firewalld
                systemctl enable firewalld
                firewall-cmd --permanent --zone=public --add-service=https
                                firewall-cmd --permanent --zone=public --add-service=http
                firewall-cmd --permanent --zone=public --add-port=5060/udp
                                firewall-cmd --permanent --zone=public --add-port=5060/tcp
                firewall-cmd --permanent --zone=public --add-port=16384-32767/udp
                firewall-cmd --reload
        fi
}

#Install Fail2ban for security

install_fail2ban()
{
                read -n 1 -p "Do you want to install and configure Fail2ban ? (y/n) "
                if [ "$REPLY"   = "y" ]; then
                        if [ -f /etc/debian_version ] ; then
                                DIST="DEBIAN"
                                apt-get -y install fail2ban
                                echo ""
                            read -p "Enter Client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /opt/ASTPP/misc/
                            tar -xzvf deb_files.tar.gz
                            mv /etc/fail2ban /tmp/
                            cp -rf /opt/ASTPP/misc/deb_files/fail2ban /etc/fail2ban

                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local
                                
                        elif  [ ${DIST} = "DEBIAN10" ]; then
                            sleep 2s
                            apt-get update -y
                            sleep 2s
                            apt-get install fail2ban -y
                            sleep 2s
                            echo ""
                            read -p "Enter Client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /usr/src
                            #wget --no-check-certificate --max-redirect=0 https://latest.astppbilling.org/fail2ban_Deb.tar.gz
                            #tar xzvf fail2ban_Deb.tar.gz
                            mv /etc/fail2ban /tmp/
                            cd ${ASTPP_SOURCE_DIR}/misc/
                            tar -xzvf fail2ban_deb10.tar.gz
                            cp -rf ${ASTPP_SOURCE_DIR}/misc/fail2ban_deb10 /etc/fail2ban
                            #cp -rf /usr/src/fail2ban /etc/fail2ban
                            #cp -rf ${ASTPP_SOURCE_DIR}/misc/deb_files/fail2ban/jail.local /etc/fail2ban/jail.local

                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local
                        elif [ -f /etc/redhat-release ] ; then
                                DIST="CENTOS"
                                yum install -y fail2ban
                                echo ""
                            read -p "Enter Client's Notification email address: ${NOTIEMAIL}"
                            NOTIEMAIL=${REPLY}
                            echo ""
                            read -p "Enter sender email address: ${NOTISENDEREMAIL}"
                            NOTISENDEREMAIL=${REPLY}
                            cd /opt/ASTPP/misc/
                            tar -xzvf cent_files.tar.gz
                            mv /etc/fail2ban /tmp/
                            cp -rf /opt/ASTPP/misc/cent_files/fail2ban /etc/fail2ban

                            sed -i -e "s/{INTF}/${INTF}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTISENDEREMAIL}/${NOTISENDEREMAIL}/g" /etc/fail2ban/jail.local
                            sed -i -e "s/{NOTIEMAIL}/${NOTIEMAIL}/g" /etc/fail2ban/jail.local
                                
                        fi
                        ################################# JAIL.CONF FILE READY ######################
                        echo "################################################################"
                        mkdir /var/run/fail2ban
                        chkconfig fail2ban on
                        systemctl restart fail2ban
                        systemctl enable fail2ban
                        echo "################################################################"
                        echo "Fail2Ban for FreeSwitch & IPtables Integration completed"
                        else
                        echo ""
                        echo "Fail2ban installation is aborted !"
                fi   
}


#Install Monit for service monitoring
install_monit ()
{
if [ ${DIST} = "DEBIAN" ]; then
apt-get -y install monit
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monit/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert on --  $EVENT $SERVICE/   subject: monit alert --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monit/monitrc
sed -i -e 's/## }/ }/g' /etc/monit/monitrc
echo '
#------------MySQL
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
    start program = "/bin/systemctl start mysql"
    stop program = "/bin/systemctl stop mysql"
if failed host 127.0.0.1 port 3306 then restart
if 5 restarts within 5 cycles then timeout

#------------Fail2ban
check process fail2ban with pidfile /var/run/fail2ban/fail2ban.pid
    start program = "/bin/systemctl start fail2ban"
    stop program = "/bin/systemctl stop fail2ban"

# ---- FreeSWITCH ----
check process freeswitch with pidfile /var/run/freeswitch/freeswitch.pid
    start program = "/bin/systemctl start freeswitch"
    stop program  = "/bin/systemctl stop freeswitch"

#-------nginx----------------------
check process nginx with pidfile /var/run/nginx.pid
    start program = "/bin/systemctl start nginx" with timeout 30 seconds
    stop program  = "/bin/systemctl stop nginx"

#-------php-fpm----------------------
check process php7.4-fpm with pidfile /var/run/php/php7.4-fpm.pid
    start program = "/bin/systemctl start php7.4-fpm" with timeout 30 seconds
    stop program  = "/bin/systemctl stop php7.4-fpm"

#--------system
check system localhost
    if loadavg (5min) > 8 for 4 cycles then alert
    if loadavg (15min) > 8 for 4 cycles then alert
    if memory usage > 80% for 4 cycles then alert
    if swap usage > 20% for 4 cycles then alert
    if cpu usage (user) > 80% for 4 cycles then alert
    if cpu usage (system) > 20% for 4 cycles then alert
    if cpu usage (wait) > 20% for 4 cycles then alert

check filesystem "root" with path /
    if space usage > 80% for 1 cycles then alert' >> /etc/monit/monitrc

systemctl restart monit
systemctl enable monit 

elif [ ${DIST} = "DEBIAN10" ]; then
cd /usr/src/
echo 'deb http://ftp.de.debian.org/debian buster-backports main' > /etc/apt/sources.list.d/buster-backports.list
sudo apt-get update -y
sudo apt-get install monit -y
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monit/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert on --  $EVENT $SERVICE/   subject: monit alert --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monit/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monit/monitrc
sed -i -e 's/## }/ }/g' /etc/monit/monitrc
echo '
#------------MySQL
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
    start program = "/bin/systemctl start mysqld"
    stop program = "/bin/systemctl stop mysqld"
if failed host 127.0.0.1 port 3306 then restart
if 5 restarts within 5 cycles then timeout

#------------Fail2ban
check process fail2ban with pidfile /var/run/fail2ban/fail2ban.pid
    start program = "/bin/systemctl start fail2ban"
    stop program = "/bin/systemctl stop fail2ban"

# ---- FreeSWITCH ----
check process freeswitch with pidfile /var/run/freeswitch/freeswitch.pid
    start program = "/bin/systemctl start freeswitch"
    stop program  = "/bin/systemctl stop freeswitch"

#-------nginx----------------------
check process nginx with pidfile /var/run/nginx.pid
    start program = "/bin/systemctl start nginx" with timeout 30 seconds
    stop program  = "/bin/systemctl stop nginx"
    
#-------php-fpm----------------------
check process php-fpm with pidfile /var/run/php-fpm/php-fpm.pid
    start program = "/bin/systemctl start php-fpm" with timeout 30 seconds
    stop program  = "/bin/systemctl stop php-fpm"

#--------system
check system localhost
    if loadavg (5min) > 8 for 4 cycles then alert
    if loadavg (15min) > 8 for 4 cycles then alert
    if memory usage > 80% for 4 cycles then alert
    if swap usage > 20% for 4 cycles then alert
    if cpu usage (user) > 80% for 4 cycles then alert
    if cpu usage (system) > 20% for 4 cycles then alert
    if cpu usage (wait) > 20% for 4 cycles then alert

check filesystem "root" with path /
    if space usage > 80% for 1 cycles then alert' >> /etc/monitrc
sleep 1s
systemctl restart monit
systemctl enable monit

elif [ ${DIST} = "CENTOS" ]; then
yum install -y monit
rm -rf /etc/monit.d
rpm --force -Uvh /var/cache/yum/x86_64/7/epel/packages/monit-*.rpm
sed -i -e 's/# set mailserver mail.bar.baz,/set mailserver localhost/g' /etc/monitrc
sed -i -e '/# set mail-format { from: monit@foo.bar }/a set alert '$EMAIL /etc/monitrc
sed -i -e 's/##   subject: monit alert --  $EVENT $SERVICE/   subject: monit alert on '${INTF}' --  $EVENT $SERVICE/g' /etc/monitrc
sed -i -e 's/## set mail-format {/set mail-format {/g' /etc/monitrc
sed -i -e 's/## }/ }/g' /etc/monitrc
echo '
#------------MySQL
check process mysqld with pidfile /var/run/mysqld/mysqld.pid
    start program = "/bin/systemctl start mysqld"
    stop program = "/bin/systemctl stop mysqld"
if failed host 127.0.0.1 port 3306 then restart
if 5 restarts within 5 cycles then timeout

#------------Fail2ban
check process fail2ban with pidfile /var/run/fail2ban/fail2ban.pid
    start program = "/bin/systemctl start fail2ban"
    stop program = "/bin/systemctl stop fail2ban"

# ---- FreeSWITCH ----
check process freeswitch with pidfile /var/run/freeswitch/freeswitch.pid
    start program = "/bin/systemctl start freeswitch"
    stop program  = "/bin/systemctl stop freeswitch"

#-------nginx----------------------
check process nginx with pidfile /var/run/nginx.pid
    start program = "/bin/systemctl start nginx" with timeout 30 seconds
    stop program  = "/bin/systemctl stop nginx"
    
#-------php-fpm----------------------
check process php-fpm with pidfile /var/run/php-fpm/php-fpm.pid
    start program = "/bin/systemctl start php-fpm" with timeout 30 seconds
    stop program  = "/bin/systemctl stop php-fpm"

#--------system
check system localhost
    if loadavg (5min) > 8 for 4 cycles then alert
    if loadavg (15min) > 8 for 4 cycles then alert
    if memory usage > 80% for 4 cycles then alert
    if swap usage > 20% for 4 cycles then alert
    if cpu usage (user) > 80% for 4 cycles then alert
    if cpu usage (system) > 20% for 4 cycles then alert
    if cpu usage (wait) > 20% for 4 cycles then alert

check filesystem "root" with path /
    if space usage > 80% for 1 cycles then alert' >> /etc/monitrc
systemctl restart monit
systemctl enable monit    
fi
}

#Configure logrotation for maintain log size
logrotate_install ()
{
if [ ${DIST} = "DEBIAN" ]; then
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/php7.4-fpm
        sed -i -e 's/rotate 12/rotate 5/g' /etc/logrotate.d/php7.4-fpm
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/nginx
        sed -i -e 's/rotate 52/rotate 5/g' /etc/logrotate.d/nginx
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit   
elif [ ${DIST} = "DEBIAN10" ]; then
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/php7.4-fpm
        sed -i -e 's/rotate 12/rotate 5/g' /etc/logrotate.d/php7.4-fpm
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/nginx
        sed -i -e 's/rotate 52/rotate 5/g' /etc/logrotate.d/nginx
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit
elif [ ${DIST} = "CENTOS" ]; then
        sed -i '7 i size 30M' /etc/logrotate.d/syslog
        sed -i '7 i rotate 5' /etc/logrotate.d/syslog
        sed -i '2 i size 30M' /etc/logrotate.d/php-fpm
        sed -i '2 i rotate 5' /etc/logrotate.d/php-fpm
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/nginx
        sed -i -e 's/rotate 10/rotate 5/g' /etc/logrotate.d/nginx
        sed -i '9 i size 30M' /etc/logrotate.d/fail2ban
        sed -i '9 i rotate 5' /etc/logrotate.d/fail2ban
        sed -i '2 i rotate 5' /etc/logrotate.d/monit
        sed -i -e 's/size 100k/size 30M/g' /etc/logrotate.d/monit
fi
}

#Remove all downloaded and temp files from server
clean_server ()
{
        cd /usr/src
        rm -rf fail2ban* GNU-AGPLv3.6.txt install.sh mysql80-community-release-el7-1.noarch.rpm
        echo "FS restarting...!"
        systemctl restart freeswitch
        echo "FS restarted...!"
}

#Installation Information Print
start_installation ()
{
        get_linux_distribution
        verification
        install_prerequisties
        license_accept
        get_astpp_source
        get_user_response
        install_mysql
        normalize_mysql
        install_freeswitch
        install_php
        install_astpp
        install_database
        normalize_freeswitch
        normalize_astpp
        configure_firewall
        install_fail2ban
        install_monit
        logrotate_install
        clean_server
        clear
        echo "******************************************************************************************"
        echo "******************************************************************************************"
        echo "******************************************************************************************"
        echo "**********                                                                      **********"
        echo "**********           Your ASTPP is installed successfully                       **********"
        echo "                     Browse URL: https://${ASTPP_HOST_DOMAIN_NAME}"
        echo "                     Username: admin"     
        echo "                     Password: admin"
        echo ""
        echo "                     MySQL root user password:"
        echo "                     ${MYSQL_ROOT_PASSWORD}"                                       
        echo ""
        echo "                     MySQL astppuser password:"
        echo "                     ${ASTPPUSER_MYSQL_PASSWORD}" 
        echo ""               
        echo "**********           IMPORTANT NOTE: Please reboot your server once.            **********"
        echo "**********                                                                      **********"
        echo "******************************************************************************************"
        echo "******************************************************************************************"
        echo "******************************************************************************************"
}
start_installation
