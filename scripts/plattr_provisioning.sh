#!/usr/bin/env bash 

/bin/bash --login


if ! yum repolist enabled | grep -q "remi"; then  
  echo "Adding EPEL repository"
  wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

  echo "Adding REMI repository"
  wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

  echo "Enabling EPEL and REMI repositories"
  sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm
  rm /home/vagrant/epel-release-6-8.noarch.rpm
  rm /home/vagrant/remi-release-6.rpm
  sudo sed -i 0,/enabled=0/{s/enabled=0/enabled=1/} /etc/yum.repos.d/remi.repo
fi

echo "Installing package dependencies"
sudo yum install java-1.8.0 --assumeyes
sudo yum install file-devel-5.04-15.el6.x86_64 --assumeyes
sudo yum install file-libs-5.04-15.el6.x86_64 --assumeyes
sudo yum install sqlite-devel-3.6.20-1.el6.x86_64 --assumeyes
sudo yum install ghostscript-8.70-19.el6.x86_64 --assumeyes
sudo yum install ImageMagick-devel-6.5.4.7-7.el6_5.x86_64 --assumeyes
sudo yum install redis-2.4.10-1.el6.x86_64 --assumeyes
sudo yum install libreoffice-headless-4.0.4.2-9.el6.x86_64 --assumeyes
sudo yum install unzip-6.0-1.el6.x86_64 --assumeyes
sudo yum install zsh-4.3.10-7.el6.x86_64 --assumeyes
sudo yum install mysql-devel-5.1.73-3.el6_5.x86_64 --assumeyes
sudo yum install nodejs --assumeyes
sudo yum install htop --assumeyes
sudo yum install gcc gettext-devel expat-devel curl-devel zlib-devel openssl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker --assumeyes

# PHP Drupal Package dependencies 
sudo yum install php-5.4.34 --assumeyes
sudo yum install php-pdo --assumeyes 
sudo yum install php-xml --assumeyes 
sudo yum install php-pecl-memcached --assumeyes 
sudo yum install php-pecl-apc --assumeyes 
sudo yum install mysql-server --assumeyes 
sudo yum install memcached --assumeyes 
sudo yum install php-posix --assumeyes
sudo yum install php-gd --assumeyes 
sudo yum install php-mbstring --assumeyes 
sudo yum install php-mysql --assumeyes

# Check if git is already installed
if ! git --version &>1 >/dev/null; then 
  echo "Installing Git"
  wget https://www.kernel.org/pub/software/scm/git/git-1.8.2.3.tar.gz
  tar xzvf git-1.8.2.3.tar.gz
  cd /home/vagrant/git-1.8.2.3
  make prefix=/usr/local all
  sudo make prefix=/usr/local install
  cd /home/vagrant
  rm git-1.8.2.3.tar.gz
  rm -rf /home/vagrant/git-1.8.2.3
fi

if [ ! -d "/opt/fits-0.6.2" ]; then 
  echo "Installing FITS"
  cd /home/vagrant
  curl -O https://fits.googlecode.com/files/fits-0.6.2.zip
  unzip fits-0.6.2.zip
  chmod +x /home/vagrant/fits-0.6.2/fits.sh
  sudo mv /home/vagrant/fits-0.6.2 /opt/fits-0.6.2
  echo 'PATH=$PATH:/opt/fits-0.6.2' >> /home/vagrant/.bashrc
  echo 'export PATH'  >> /home/vagrant/.bashrc
  source /home/vagrant/.bashrc
fi

# Check if RVM is already installed
if ! rvm --version &>1 >/dev/null; then 
  echo "Installing RVM"
  cd /home/vagrant
  \curl -sSL https://get.rvm.io | bash
  source /home/vagrant/.profile
  rvm pkg install libyaml
  rvm install ruby-2.0.0-p481
  rvm --default use ruby-2.0.0-p481
  source /home/vagrant/.rvm/scripts/rvm
fi 

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
thor drupal_jetty:init
rails g cerberus_core:exist --skip

# rake jetty:start throws an ugly/alarming error if called when the 
# server is already running, so check first. 
if rake jetty:status | grep -q "not running"; then 
  rake jetty:start
fi

echo "Starting Redis" 
sudo service redis start 

if [ ! -f "/usr/local/bin/composer" ]; then 
  echo "Installing composer"
  curl -sS https://getcomposer.org/installer | php 
  sudo mv composer.phar /usr/local/bin/composer 
  export PATH=$PATH:/home/vagrant/.composer/vendor/bin
  echo "Installing Drush"
  composer global require "drush/drush:6.*"
fi 

if [ ! -d "/home/vagrant/.oh-my-zsh" ]; then 
  echo "Installing Oh-My-Zsh"
  cd /home/vagrant 
  \curl -Lk http://install.ohmyz.sh | sh 
  sudo chsh -s /bin/zsh vagrant 
  # Set the default theme to something that doesn't try to load git
  # info on navigation; the tapas directory is large enough that this 
  # is incredibly slow 
  sed -i "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"evan\"/g" /home/vagrant/.zshrc
  # Ensure rvm is available from .zshrc
  rvm get stable --auto-dotfiles
  rvm alias create default ruby-2.0.0-p481
fi

echo "Setting required services to auto start"
sudo chkconfig redis on 
sudo chkconfig mysqld on 
sudo chkconfig memcached on 
sudo chkconfig httpd on 

echo "Configuring PHP"
sudo sed -i "s/max_execution_time = 30/max_execution_time = 120/g" /etc/php.ini
sudo sed -i "s/post_max_size = 8M/post_max_size = 50M/g" /etc/php.ini
sudo sed -i "s/memory_limit = 128M/memory_limit = 400M/g" /etc/php.ini

echo "Setting up tapas" 
# We need to override the `AllowOverride None` on DocumentRoot (/var/www/html). 
# The `Include conf.d/*.conf` line in httpd.conf occurs before the directive, 
# so any changes made to it that way fail.  
tapas_conf="Include /home/vagrant/requirements/tapas.conf" 
if ! grep -q $tapas_conf /etc/httpd/conf/httpd.conf; then  
  echo "Configuring httpd.conf"
  echo $tapas_conf | sudo tee --append  /etc/httpd/conf/httpd.conf >/dev/null
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


cd /home/vagrant 
if ! composer global show -i | grep -q "d11wtq/boris"; then 
  echo "Installing boris and boris-loader (Drupal REPL)" 
  git clone http://github.com/tobiassjosten/boris-loader 
  composer global require 'd11wtq/boris=*'
  cp /home/vagrant/requirements/borisrc_base /home/vagrant/.borisrc
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
sudo service mysqld restart 

# Execute user specific provisioning script
if [ -f /home/vagrant/requirements/local/local.sh ]; then 
  sh /home/vagrant/requirements/local/local.sh
fi
