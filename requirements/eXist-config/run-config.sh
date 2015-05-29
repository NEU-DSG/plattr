#!/usr/bin/env bash

# EXIST-DB CONFIGURATION SCRIPT
# Backs up configuration files to "ORIGFILE.ORIGEXTENSION.orig" before making 
#  changes to the components that eXist uses.
# Assumes that you have just:
#       - installed eXist
#       - set and sourced the $EXIST_HOME and $JAVA_HOME environment variables
# IMPORTANT: Make sure eXist is shut down before running this script!

# Last modified: May 2015
# Author: Ashley M. Clark
new_port='8868'
set_sysuser='true'

if [$new_port!='8080']; then
  echo "Configuring eXist to use port $new_port"
  mv $EXIST_HOME/tools/jetty/etc/jetty.xml $EXIST_HOME/tools/jetty/etc/jetty.xml.orig
  sed 's/8080/$new_port/g' $EXIST_HOME/tools/jetty/etc/jetty.xml.orig > $EXIST_HOME/tools/jetty/etc/jetty.xml
fi
echo "Running configuration stylesheets"
mv $EXIST_HOME/conf.xml $EXIST_HOME/conf.xml.orig
java -jar $EXIST_HOME/lib/endorsed/saxonhe*.jar -s:$EXIST_HOME/conf.xml.orig -xsl:/home/vagrant/requirements/eXist-config/startup-and-db-config.xsl -o:$EXIST_HOME/conf.xml
mv $EXIST_HOME/webapp/WEB-INF/controller-config.xml $EXIST_HOME/webapp/WEB-INF/controller-config.xml.orig
java -jar $EXIST_HOME/lib/endorsed/saxonhe*.jar -s:$EXIST_HOME/webapp/WEB-INF/controller-config.xml.orig -xsl:/home/vagrant/requirements/eXist-config/network-servlet-management.xsl -o:$EXIST_HOME/webapp/WEB-INF/controller-config.xml
mv $EXIST_HOME/webapp/WEB-INF/web.xml $EXIST_HOME/webapp/WEB-INF/web.xml.orig
java -jar $EXIST_HOME/lib/endorsed/saxonhe*.jar -s:$EXIST_HOME/webapp/WEB-INF/web.xml.orig -xsl:/home/vagrant/requirements/eXist-config/network-servlet-management.xsl -o:$EXIST_HOME/webapp/WEB-INF/web.xml

# Give an eXist-specific user ownership over $EXIST_HOME and running the service
if [$set_sysuser=='true']; then
  if [grep 'existdb' /etc/passwd]; then 
    echo "Adding a system user account for eXist"
    sudo useradd -r -U existdb
  fi
  echo "Giving ownership of $EXIST_HOME to user 'existdb'"
  sudo chown existdb:existdb $EXIST_HOME
  sed -E "s/^#(RUN_AS_USER=)$/\1existdb/g" $EXIST_HOME/tools/wrapper/bin/exist.sh
fi
# Point eXist to the generalized Java symbolic link (to the currently-used version.)
sed -E "s/(\/usr\/lib\/jvm\/java).*(\/jre\/bin\/java)$/\1\2/g" $EXIST_HOME/tools/wrapper/conf/wrapper.conf
# Make eXist a service, using a built-in script.
echo "Configuring eXist to start on boot"
if [ -f /etc/init.d/existdb ]; then
	if [ -h /etc/init.d/existdb ]; then
		sudo ln -s -f $EXIST_HOME/tools/wrapper/bin/exist.sh /etc/init.d/existdb
	else
		echo "/etc/init.d/existdb points at an actual file.  Aborting!"
	fi
else
	sudo ln -s $EXIST_HOME/tools/wrapper/bin/exist.sh /etc/init.d/existdb
fi
sudo chkconfig --add existdb
