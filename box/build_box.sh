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
sudo yum install httpd-2.2.15 --assumeyes
sudo yum install file-devel-5.04-21.el6.x86_64 --assumeyes
sudo yum install file-libs-5.04-21.el6.x86_64 --assumeyes
sudo yum install sqlite-devel-3.6.20-1.el6.x86_64 --assumeyes
sudo yum install ghostscript-8.70-21.el6.x86_64 --assumeyes
sudo yum install ImageMagick-devel-6.7.2.7-2.el6.x86_64 --assumeyes
sudo yum install redis-2.4.10-1.el6.x86_64 --assumeyes
sudo yum install libreoffice-headless-4.2.8.2-11.el6.x86_64 --assumeyes
sudo yum install unzip-6.0-1.el6.x86_64 --assumeyes
sudo yum install zsh-4.3.11-4.el6.centos.x86_64 --assumeyes
sudo yum install mysql-server-5.5.45-1.el6.remi.x86_64 --assumeyes
sudo yum install mysql-devel-5.5.45-1.el6.remi.x86_64 --assumeyes
sudo yum install nodejs --assumeyes
sudo yum install htop --assumeyes
sudo yum install gcc gettext-devel expat-devel curl-devel zlib-devel openssl-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker --assumeyes
sudo yum install httpd-devel --assumeyes 
sudo yum install curl-devel --assumeyes

# PHP Drupal Package dependencies 
sudo yum install php-5.4.38 --assumeyes
sudo yum install php-pdo --assumeyes 
sudo yum install php-xml --assumeyes 
sudo yum install php-pecl-memcached --assumeyes 
sudo yum install php-pecl-apc --assumeyes 
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
  rm /home/vagrant/fits-0.6.2.zip
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

# Install passenger as a global gem 
rvm use ruby-2.0.0-p481
chmod o+x /home/vagrant
gem install passenger -v 5.0.15
passenger-install-apache2-module --auto
sudo cp -f /vagrant/requirements/httpd.conf /etc/httpd/conf/httpd.conf
echo "127.0.0.1   rails_api.localhost" | sudo tee -a /etc/hosts
echo "127.0.0.1   drupal.localhost" | sudo tee -a /etc/hosts

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

cd /home/vagrant 
if ! composer global show -i | grep -q "d11wtq/boris"; then 
  echo "Installing boris and boris-loader (Drupal REPL)" 
  git clone http://github.com/tobiassjosten/boris-loader 
  composer global require 'd11wtq/boris=*'
  cp /vagrant/borisrc_base /home/vagrant/.borisrc
fi

echo "Fixing .zshrc file" 
cp -f /vagrant/requirements/zshrc /home/vagrant/.zshrc
