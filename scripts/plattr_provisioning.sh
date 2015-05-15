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
sleep 15s # <--- might be able to reduce this?
thor exist_jetty:set_permissions

echo "Starting Redis" 
sudo service redis start 

echo "Setting up tapas" 
sudo chown -R vagrant /var/www/html 
mkdir /var/www/html/tapas
echo "export PATH=\$PATH:/home/vagrant/.composer/vendor/bin" >> /home/vagrant/.bashrc
# buildtapas script places the site in the directory it is executed from
cd /var/www/html/tapas
/bin/bash --login /home/vagrant/buildtapas/buildtapas.sh "root" "" "tapas_drupal" "drupaldb" "drupaldb"

# We need to override the `AllowOverride None` on DocumentRoot (/var/www/html). 
# The `Include conf.d/*.conf` line in httpd.conf occurs before the directive, 
# so any changes made to it that way fail.  
tapas_conf="Include /vagrant/requirements/tapas.conf" 
if ! grep -q 'Include /vagrant/requirements/tapas.conf' /etc/httpd/conf/httpd.conf; then  
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

# Set the apache user's uid to mirror that of the user who owns the tapas/ 
# nfs mounted directory.  Sorts out permissions well enough for the sake of 
# a dev environment.
# Note that this will not do anything if the uid of the apache user on the 
# vagrant vm would conflict with a uid assigned to another user after the change.
sudo service httpd stop 
sudo usermod -u $1 apache 

echo "Restarting necessary services"
sudo service httpd restart
sudo service memcached restart 
sudo service redis restart
sudo service mysqld restart 

# Execute user specific provisioning script
if [ -f /vagrant/requirements/local/local.sh ]; then 
  sh /vagrant/requirements/local/local.sh
fi
