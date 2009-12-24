#!/bin/bash

#-- User Defined Variables --#
site=''	#Domain of the site you want to host
site_db=''	#Name of the MySQL wordpress database
site_db_user=''	#Database user account
site_db_passwd=''	#Database password
mysql_host='localhost'	#MySQL host (usually localhost unless you have a seperate database server)
mysql_root_user='root'	#MySQL root user (usually leave this as root)
mysql_root_passwd=''	#Root password for MySQL you setup during server setup
sudo_user=''	#Your server username
#-- UDVs End --#

check_vars()
{
  if [ -n "$site" -a -n "$site_db" -a -n "$site_db_user" -a -n "$site_db_passwd" -a -n "$mysql_host" -a -n "$mysql_root_user" -a -n "$mysql_root_passwd" -a -n "$sudo_user" ]
  then
    return
  else
    echo "Value of variables cannot be empty."
    exit
  fi
}

cleanup()
{
  rm -rf tmp/*
}

create_site()
{
  local opt=""
  if [ -e "/home/public_html/$site" -a -e "/etc/nginx/sites-available/$site" ]
  then
    echo "Site is already created on Nginx!"
    echo "Do you want to continue?"
    echo "WARNING: all current files in /home/public_html/$site/public will be deleted if you continue!!!"
    while [ "$opt" != "y" -a "$opt" != "Y"  -a "$opt" != "n" -a "$opt" != "N" ]
    do
      read -p "[y/n] : " opt
      if [ "$opt" = "N" -o "$opt" = "n" ]; then
        echo "Wordpress installation aborted!"
        exit
      fi
      if [ "$opt" = "Y" -o "$opt" = "y" ]; then
        echo -n "Cleaning up /home/public_html/$site/public/..."
        rm -rf /home/public_html/$site/public/*
        echo "done."
      fi
    done
  else
    echo -n "Creating site on nginx..."
    mkdir /home/public_html/$site && cd /home/public_html/$site && mkdir public private log backup && cd -
    chown -R $sudo_user.webmasters /home/public_html
    find /home/public_html -type d -exec chmod g+s {} \; > /dev/null 2>&1
    cp files/mydomain.com tmp/domain.$$
    sed -i -r "s/mydomain.com/$site/g" tmp/domain.$$
    cp tmp/domain.$$ /etc/nginx/sites-available/$site
    ln -s /etc/nginx/sites-available/$site  /etc/nginx/sites-enabled/$site
    /etc/init.d/nginx restart > /dev/null 2>&1
    echo "done."
  fi
}

setup_wp()
{
  if [ -d /var/lib/mysql/$site_db ]; then
    echo "Database $site_db aready exists! Wordpress installation aborted!"
    exit
  fi
  echo -n "Installing Wordpress..."
  cd tmp
  wget http://wordpress.org/latest.tar.gz
  tar xzf latest.tar.gz > /dev/null 2>&1
  mv wordpress/* /home/public_html/$site/public/
  cd ..
  mysqladmin -u $mysql_root_user -p$mysql_root_passwd create $site_db
  { echo "use mysql;"
    echo grant all on ${site_db}.* to "$site_db_user"@'localhost' identified by "'${site_db_passwd}';"
    echo "flush privileges;"
  } > tmp/sql.$$
  mysql -u $mysql_root_user -p$mysql_root_passwd $site_db < tmp/sql.$$
  chown -R $www-data.webmasters /home/public_html
  echo "done."
}

print_report()
{
  echo "WP install script: http://$site/"
  echo "Database to be used: $site_db"
  echo "Database user: $site_db_user"
  echo "Database user password: $site_db_passwd"
}

# clean up tmp
cleanup

# check value of all UDVs
check_vars

# create the site on nginx
create_site

# setup Wordpress
setup_wp

# print WP installation report
print_report

# clean up tmp
cleanup
