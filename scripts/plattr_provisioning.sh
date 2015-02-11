#!/usr/bin/env bash 
/bin/bash --login

echo "Configuring tapas_rails"
cd /home/vagrant/tapas_rails
gem install bundler 
bundle install 
rake db:migrate

# rails g hydra:jetty attempts to wget down a zipfile from 
# Github containing the entire tapas/jetty directory - because 
# we are version locked to an old version of jetty and because 
# the tagged zipfile we expect to exist no longer actually exists, 
# this breaks UNLESS we wget down the proper zip into the tmp/ 
# dir, where the generator checks before downloading anything.
# Do this here.
if [ -f "/home/vagrant/tapas_rails/tmp/new-solr-schema.zip" ]; then 
	echo "new-solr-schema.zip already exists - skipping wget" 
else 
	loc='http://librarystaff.neu.edu/DRSzip/new-solr-schema.zip'
	wget -P /home/vagrant/tapas_rails/tmp $loc
fi 

if [ ! -d /home/vagrant/tapas_rails/jetty ]; then 
  rails g hydra:jetty
  rake jetty:config
fi

rake db:test:prepare 

if rake jetty:status | grep -q "^Running"; then 
  rake jetty:stop 
fi

thor drupal_jetty:init
thor exist_jetty:init

# rake jetty:start throws an ugly/alarming error if called when the 
# server is already running, so check first. 
if rake jetty:status | grep -q "Not running"; then 
  rake jetty:start
fi
# So that eXist works better out-of-the-box, set its admin password
# and change its default database permissions.
echo "Giving Jetty some time to start"
sleep 20s
thor exist_jetty:set_permissions

echo "Starting Redis" 
sudo service redis start 

echo "Setting up tapas" 
# We need to override the `AllowOverride None` on DocumentRoot (/var/www/html). 
# The `Include conf.d/*.conf` line in httpd.conf occurs before the directive, 
# so any changes made to it that way fail.  
tapas_conf="Include /home/vagrant/requirements/tapas.conf" 
if ! grep -q 'Include /home/vagrant/requirements/tapas.conf' /etc/httpd/conf/httpd.conf; then  
  echo "Configuring httpd.conf"
  echo $tapas_conf | sudo tee --append /etc/httpd/conf/httpd.conf >/dev/null
fi

echo "Symlinking vagrant config files" 
# Function for testing whether symlink already exists, or if an
# actual config file exists at the symlink location.  
# Overwrites symlinks, doesn't overwrite real files. 
safeish_symlink(){
  path=$1
  target=$2

  if [ -f $target ]; then
    if [ -h $target ]; then 
      ln -s -f $path $target
    else 
      echo "$target points at an actual file.  Aborting!"
    fi 
  else
    ln -s $path $target 
  fi
}

safeish_symlink /var/www/html/tapas/sites/default/settings.vagrant.php /var/www/html/tapas/sites/default/settings.php
safeish_symlink /var/www/html/tapas/.htaccess.vagrant /var/www/html/tapas/.htaccess 

sudo service mysqld start
if ! mysql -u root -e "use drupal_tapas"; then 
  echo "Creating and cloning database"
  mysql -u root --password='' --execute="CREATE DATABASE drupal_tapas;"
  # Configure mysql to handle the very large blobs of data in the sql 
  # dumpfile. 
  mysql -u root --password='' --execute="set global net_buffer_length=100000000;"
  mysql -u root --password='' --execute="set global max_allowed_packet=100000000000;"
  mysql --max_allowed_packet=2G -u root --password='' drupal_tapas < /vagrant/requirements/drupal_tapas_minimal.sql
fi

# Set the apache user's uid to mirror that of the user who owns the tapas/ 
# nfs mounted directory.  Sorts out permissions well enough for the sake of 
# a dev environment.
# Note that this will not do anything if the uid of the apache user on the 
# vagrant vm would conflict with a uid assigned to another user after the change.
sudo usermod -u $1 apache 

echo "Restarting necessary services"
sudo service httpd restart
sudo service memcached restart 
sudo service redis restart
sudo service mysqld restart 

# Execute user specific provisioning script
if [ -f /home/vagrant/requirements/local/local.sh ]; then 
  sh /home/vagrant/requirements/local/local.sh
fi
