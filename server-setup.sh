#!/bin/bash

#-- User Defined Variables --#
hostname=''    #Your hostname (e.g. server.example.com)
sudo_user=''    #Your username
sudo_user_passwd=''     #your password
root_passwd=''    #Your new root password
ssh_port='22'   #Your SSH port if you wish to change it from the default
#-- UDV End --#

set_locale()
{
  echo -n "Setting up system locale..."
  { locale-gen en_US.UTF-8
    unset LANG
    /usr/sbin/update-locale LANG=en_US.UTF-8
  } > /dev/null 2>&1
  export LANG=en_US.UTF-8
  echo "done."
}  

set_hostname()
{
  if [ -n "$hostname" ]
  then
    echo -n "Setting up hostname..."
    hostname $hostname
    echo $hostname > /etc/hostname
    echo "127.0.0.1 $hostname" >> /etc/hostname
    echo "done."
  fi
}

change_root_passwd()
{
  if [ -n "$root_passwd" ]
  then
    echo -n "Changing root password..."
    echo "$root_passwd\n$root_passwd" > tmp/rootpass.$$
    passwd root < tmp/rootpass.$$ > /dev/null 2>&1
    echo "done."
  fi
}

create_sudo_user()
{
  if [ -n "$sudo_user" -a -n "$sudo_user_passwd" ]
  then
    id $sudo_user > /dev/null 2>&1 && echo "Cannot create sudo user! User $sudo_user already exists!" && touch tmp/sudofailed.$$ && return
    echo -n "Creating sudo user..."
    useradd -d /home/$sudo_user -s /bin/bash -m $sudo_user
    echo "$sudo_user_passwd\n$sudo_user_passwd" > tmp/sudopass.$$
    passwd $sudo_user < tmp/sudopass.$$ > /dev/null 2>&1
    echo "$sudo_user ALL=(ALL) ALL" >> /etc/sudoers
    { echo 'export PS1="\[\e[32;1m\]\u\[\e[0m\]\[\e[32m\]@\h\[\e[36m\]\w \[\e[33m\]\$ \[\e[0m\]"'
      echo 'alias ll="ls -la"'
      echo 'alias a2r="sudo /etc/init.d/apache2 stop && sleep 2 && sudo /etc/init.d/apache2 start"'
      echo 'alias n2r="sudo /etc/init.d/nginx stop && sleep 2 && sudo /etc/init.d/nginx start"'
      echo 'alias ver="cat /etc/lsb-release"'
    } >> /home/$sudo_user/.bashrc
    echo "done."
  fi
}

config_ssh()
{
  conf='/etc/ssh/sshd_config'
  echo -n "Configuring SSH..."
  sed -i -r 's/\s*X11Forwarding\s+yes/X11Forwarding no/g' $conf
  sed -i -r 's/\s*UsePAM\s+yes/UsePAM no/g' $conf
  sed -i -r 's/\s*UseDNS\s+yes/UseDNS no/g' $conf
  grep -q "UsePAM no" $conf || echo "UsePAM no" >> $conf
  grep -q "UseDNS no" $conf || echo "UseDNS no" >> $conf
  if [ -n "$ssh_port" ]
  then
    sed -i -r "s/\s*Port\s+[0-9]+/Port $ssh_port/g" $conf 
    cp files/iptables.up.rules tmp/fw.$$
    sed -i -r "s/\s+22\s+/ $ssh_port /" tmp/fw.$$
  fi
  if id $sudo_user > /dev/null 2>&1 && [ ! -e tmp/sudofailed.$$ ]
  then
    sed -i -r 's/\s*PermitRootLogin\s+yes/PermitRootLogin no/g' $conf
    echo "AllowUsers $sudo_user" >> $conf
  fi
  echo "done."
}

setup_firewall()
{
  echo -n "Setting up firewall..."
  cp tmp/fw.$$ /etc/iptables.up.rules
  iptables -F
  iptables-restore < /etc/iptables.up.rules > /dev/null 2>&1 &&
  sed -i 's%pre-up iptables-restore < /etc/iptables.up.rules%%g' /etc/network/interfaces
  sed -i -r 's%\s*iface\s+lo\s+inet\s+loopback%iface lo inet loopback\npre-up iptables-restore < /etc/iptables.up.rules%g' /etc/network/interfaces
  /etc/init.d/ssh reload > /dev/null 2>&1
  echo "done."
}

install_pkg()
{
  echo "Installing packages."
  sleep 1
  aptitude update
  aptitude -y safe-upgrade
  aptitude -y full-upgrade
  aptitude -y install screen build-essential php5-common php5-dev php5-mysql php5-sqlite php5-tidy php5-xmlrpc php5-xsl php5-cgi php5-mcrypt php5-curl php5-gd php5-memcache php5-mhash php5-pspell php5-snmp php5-sqlite libmagick9-dev php5-cli 
  aptitude -y install make php-pear
  echo "Installing ImageMagick PHP module. Just press <ENTER> at prompt.\n"
  sleep 1
  pecl install imagick
  echo "extension=imagick.so" >> /etc/php5/cgi/php.ini
  sed -i -r 's/\s*memory_limit\s+=\s+16M/memory_limit = 48M/g' /etc/php5/cgi/php.ini
  aptitude -y install mysql-server mysql-client libmysqlclient15-dev
  mysql_secure_installation
  aptitude -y install subversion git-core vsftpd
  echo "Installing Postfix mail server\n"
  echo "Select 'Internet Site', and then for 'System mail name:' -> $hostname\n".
  sleep 2
  aptitude -y install dnsutils postfix telnet mailx
  grep "root: $sudo_user" /etc/aliases > /dev/null 2>&1 || echo "root: $sudo_user" >> /etc/aliases
  newaliases
  aptitude -y install nginx
  aptitude -y install libfcgi0
  echo "Done."
}

config_web()
{
  mkdir /etc/nginx/conf/
  cp files/wp.conf /etc/nginx/conf/
  cp files/wp_super_cache.conf /etc/nginx/conf/
  cp files/php-fastcgi /etc/default/ 
  cp files/php-fastcgi-rc /etc/init.d/php-fastcgi
  chmod +x /etc/init.d/php-fastcgi
  mkdir /home/public_html
  groupadd webmasters
  usermod -G webmasters $sudo_user
  usermod -G webmasters www-data
  chown -R $sudo_user.webmasters /home/public_html
  chmod -R g+w /home/public_html
  find /home/public_html -type d -exec chmod g+s {} \;
  /etc/init.d/nginx start
  /etc/init.d/php-fastcgi start
}

copy_site_setup_files()
{
  mkdir /home/$sudo_user/wp-setup
  cp wordpress-setup.sh /home/$sudo_user/wp-setup/wordpress-setup.sh
  mkdir /home/$sudo_user/wp-setup/files
  cp files/mydomain.com /home/$sudo_user/wp-setup/files/mydomain.com	
  mkdir /home/$sudo_user/wp-setup/tmp
  chown -R $sudo_user /home/$sudo_user
  chmod -R +x /home/$sudo_user
}

check_vars()
{
  if [ -n "$hostname" -a -n "$sudo_user" -a -n "$sudo_user_passwd" -a -n "$root_passwd" -a -n "$ssh_port" ]
  then
    return
  else
    echo "Value of variables cannot be empty."
  fi
}

cleanup()
{
  rm -rf tmp/*
}

#-- Function calls and flow of execution --#

# clean up tmp
cleanup

# check value of all UDVs
check_vars

# set host name of server
set_hostname

# set system locale
set_locale

# change root user password
change_root_passwd

# create and configure sudo user
create_sudo_user

# configure ssh
config_ssh

# set up and activate firewall
setup_firewall

# install packages
install_pkg

# configure nginx web server
config_web

# copy over site setup files
copy_site_setup_files

# clean up tmp
cleanup
