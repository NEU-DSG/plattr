#!/usr/bin/env bash 
/bin/bash --login

# Before doing anything else, verify that the specified buildtapas branch 
# exists on github and is accessible.
branch=$2
buildtapas_repo="https://github.com/neu-dsg/buildtapas.git"
all_repos=$(git ls-remote -h $buildtapas_repo $branch)

# This check ensures that we are getting an exact match on our branch
if [[ $all_repos != *"refs/heads/$branch"* ]]; then
  echo "There is no buildtapas branch on github named $branch" >&2
  exit 1
fi

# Update composer
/usr/local/bin/composer self-update
# Update drush
composer global require "drush/drush:dev-master#e264dac550ae0705cc5b016f3cf9e73ea581777f"
# Update boris-loader
cd /home/vagrant/boris-loader
git pull origin master 

echo "Configuring tapas_rails"
cd /home/vagrant/tapas_rails
gem install bundler 
bundle install 
rake db:migrate
thor tapas_rails:create_api_user

# Fix firewall rules
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT 
sudo iptables -I INPUT -p tcp --dport 8868 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8983 -j ACCEPT 
sudo /sbin/service iptables save

# Install Phusion Passenger
chmod o+x /home/vagrant 
bundle exec passenger-install-apache2-module --auto 
sudo cp -f /vagrant/requirements/httpd.conf /etc/httpd/conf/httpd.conf 
echo "127.0.0.1   rails_api.localhost drupal.localhost" | sudo tee -a /etc/hosts

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

# rake jetty:start throws an ugly/alarming error if called when the 
# server is already running, so check first. 
if rake jetty:status | grep -q "Not running"; then 
  rake jetty:start
fi

echo "Starting Redis" 
sudo service redis start 

echo "Setting up tapas" 
sudo chown -R vagrant /var/www/html 
echo "export PATH=\$PATH:/home/vagrant/.composer/vendor/bin" >> /home/vagrant/.bashrc
# buildtapas script places the site in the directory it is executed from
cd /var/www/html
curl -O https://raw.githubusercontent.com/neu-dsg/buildtapas/$branch/buildtapas.sh
sed -i.bak 's/8080/3306/g' buildtapas.sh
/bin/bash --login /var/www/html/buildtapas.sh "root" "" "tapas_drupal" "drupaldb" "drupaldb"

# Set the admin password to always be 'admin'
cd /var/www/html
drush upwd admin --password="admin"

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


# Remove out-of-date installations of eXist (as implemented
# by cerberus-core or tapas_rails).
echo "Searching for out-of-date, Hydra-dependent installations of eXist-db..."
cd /home/vagrant/tapas_rails
git clean -f -d -x jetty/webapps/exist*
git clean -f -x jetty/contexts/exist*
git clean -f -x config/exist.yml
echo "Proceeding."

# Install the latest version of eXist that TAPAS supports.
# the eXist version number
new_exist_vers="2.2"
# the name of the eXist installer file
new_exist_jar="eXist-db-setup-2.2.jar"
# the link to download the installer
new_exist_url="http://sourceforge.net/projects/exist/files/Stable/${new_exist_vers}/${new_exist_jar}"
if [ ! -d "/home/vagrant/.eXist/eXist-${new_exist_vers}" ]; then 
	echo "Installing eXist-DB"
	# Ensure the .eXist directory is present.
	if [ ! -d "/home/vagrant/.eXist" ]; then
		mkdir /home/vagrant/.eXist
	fi
  # Ensure the requirements/local directory is present.
  if [ ! -d "/vagrant/requirements/local" ]; then
    mkdir /vagrant/requirements/local
  fi
  # Download the eXist installer to requirements/local for persistence over box rebuilds.
  if [ -f "/vagrant/requirements/local/${new_exist_jar}" ]; then
    echo "Latest eXist installer already available - skipping download"
  else
    echo "Downloading the latest TAPAS-supported eXist installer"
    wget -nv -P /vagrant/requirements/local $new_exist_url
  fi
	# Install eXist using the auto-install script.
	echo "Installing eXist-${new_exist_vers}"
	java -jar /vagrant/requirements/local/$new_exist_jar /vagrant/requirements/eXist-config/auto-install.xml
	# Create symlink "latest-eXist".
	safeish_symlink "/home/vagrant/.eXist/eXist-${new_exist_vers}" /home/vagrant/latest-eXist
	# Ensure EXIST_HOME and JAVA_HOME environment variables are set.
	if [ -z $JAVA_HOME ]; then
		echo "export JAVA_HOME=/etc/alternatives/jre" >> /home/vagrant/.zprofile
	fi
	if [ -z $EXIST_HOME ]; then
		echo "export EXIST_HOME=/home/vagrant/latest-eXist" >> /home/vagrant/.zprofile
	fi
	source /home/vagrant/.zprofile
	echo "JAVA_HOME is set to: $JAVA_HOME"
	echo "EXIST_HOME is set to: $EXIST_HOME"
	
	sh /vagrant/requirements/eXist-config/run-config.sh
fi
sudo service existdb start

# Set the apache user's uid to mirror that of the user who owns the tapas/ 
# nfs mounted directory.  Sorts out permissions well enough for the sake of 
# a dev environment.
# Note that this will not do anything if the uid of the apache user on the 
# vagrant vm would conflict with a uid assigned to another user after the change.
sudo service httpd stop 
sudo usermod -u $1 apache 

# Copies in a version of my.cnf that has defaults that will work with Drupal
sudo mv /etc/my.cnf /etc/my.cnf.bak 
sudo cp -f /vagrant/requirements/my.cnf /etc/my.cnf 

# InnoDB logs on the base device are a different size than in the new cfg,
# causing SQL to fail to start unless we remove them.

sudo mv /var/lib/mysql/ib_logfile0 /var/lib/mysql/bak_ib_logfile0.bak
sudo mv /var/lib/mysql/ib_logfile1 /var/lib/mysql/bak_ib_logfile1.bak

echo "Restarting necessary services"
sudo service httpd restart
sudo service memcached restart 
sudo service redis restart
sudo service mysqld restart 

# Execute user specific provisioning script
if [ -f /vagrant/requirements/local/local.sh ]; then 
  sh /vagrant/requirements/local/local.sh
fi
