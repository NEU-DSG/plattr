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
#thor exist_jetty:init

# rake jetty:start throws an ugly/alarming error if called when the 
# server is already running, so check first. 
if rake jetty:status | grep -q "Not running"; then 
  rake jetty:start
fi
# So that eXist works better out-of-the-box, set its admin password
# and change its default database permissions.
#echo "Giving Jetty some time to start"
#sleep 20s
#thor exist_jetty:set_permissions

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

# Install the latest version of eXist that TAPAS supports.
#cd /home/vagrant
new_exist_vers="2.2"	# the eXist version number
new_exist_jar="eXist-db-setup-2.2.jar"	# the name of the eXist installer file
new_exist_url="http://sourceforge.net/projects/exist/files/Stable/2.2/${new_exist_jar}"	# the link to download the installer
if [ ! -d "/home/vagrant/.eXist/eXist-${new_exist_vers}" ]; then 
	echo "Installing eXist-DB"
	# Ensure the .eXist directory is present.
	if [ ! -d "/home/vagrant/.eXist" ]; then
		mkdir /home/vagrant/.eXist
	fi
	# Ensure the requirements/local directory is present.
	if [ ! -d "/home/vagrant/requirements/local" ]; then
		mkdir /home/vagrant/requirements/local
	fi
	# Download the eXist installer to requirements/local for persistence over box rebuilds.
	if [ -f "/home/vagrant/requirements/local/${new_exist_jar}" ]; then
		echo "Latest eXist installer already available - skipping download"
	else
		echo "Downloading the latest TAPAS-supported eXist installer"
		wget -nv -P /home/vagrant/requirements/local $new_exist_url
	fi
	# Install eXist using the auto-install script.
	echo "Installing eXist-${new_exist_vers}"
	java -jar /home/vagrant/requirements/local/$new_exist_jar /home/vagrant/requirements/auto-install-eXist.xml
	# Back up the original jetty.xml before editing ports.
	mv /home/vagrant/.eXist/eXist-$new_exist_vers/tools/jetty/etc/jetty.xml /home/vagrant/.eXist/eXist-$new_exist_vers/tools/jetty/etc/jetty.xml.tmpl
	echo "Configuring eXist to use port 8868"
	sed 's/8080/8868/g' /home/vagrant/.eXist/eXist-$new_exist_vers/tools/jetty/etc/jetty.xml.tmpl > /home/vagrant/.eXist/eXist-$new_exist_vers/tools/jetty/etc/jetty.xml
	# Symlink through "latest-eXist" directory.
	safeish_symlink "/home/vagrant/.eXist/eXist-${new_exist_vers}" /home/vagrant/latest-eXist
	# Ensure EXIST_HOME and JAVA_HOME environment variables are set.
	if [ -z $JAVA_HOME ]; then
		echo "export JAVA_HOME=/usr/lib/jre" >> /home/vagrant/.zprofile
	fi
	if [ -z $EXIST_HOME ]; then
		echo "export EXIST_HOME=/home/vagrant/latest-eXist" >> /home/vagrant/.zprofile
	fi
	source /home/vagrant/.zprofile
	echo "JAVA_HOME is set to: $JAVA_HOME"
	echo "EXIST_HOME is set to: $EXIST_HOME"
	echo "Adding wrapper scripts to start eXist on reboot"
	if [ -f /etc/init.d/exist-db ]; then
		if [ -h /etc/init.d/exist-db ]; then
			sudo ln -s -f /home/vagrant/latest-eXist/tools/wrapper/bin/exist.sh /etc/init.d/exist-db
		else
			echo "/etc/init.d/exist-db points at an actual file.  Aborting!"
		fi
	else
		sudo ln -s /home/vagrant/latest-eXist/tools/wrapper/bin/exist.sh /etc/init.d/exist-db
	fi
	sudo chkconfig --add exist-db
fi
sudo service exist-db start

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
sudo service httpd stop 
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
