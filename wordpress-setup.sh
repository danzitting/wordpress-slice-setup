site_domain=   #Your wordpress domain (e.g. example.com)

setup_site()
{
  mkdir /home/public_html/$1 && cd /home/public_html/$1 && mkdir public private log backup && cd -
  find /home/public_html -type d -exec chmod g+s {} \;
  cp files/mydomain.com tmp/domain.$$
  sed -i -r "s/mydomain.com/$1/g" tmp/domain.$$
  cp tmp/domain.$$ /etc/nginx/sites-available/$1
  ln -s /etc/nginx/sites-available/$1  /etc/nginx/sites-enabled/$1
  /etc/init.d/nginx restart
}

wordpress_setup()
{
  cd tmp
  wget http://wordpress.org/latest.tar.gz
  tar -xzvf latest.tar.gz
  mv wordpress/* /home/public_html/$site_domain/public
}

check_vars()
{
  if [ -n "$site_domain" ]
  then
    return
  else
    echo "You must set the site_domain variable to your domain name."
  fi
}

cleanup()
{
  rm -rf tmp/*
}


# set up a domain on nginx
setup_site $site_domain

# install wordpress
wordpress_setup $site_domain

# clean up tmp
cleanup