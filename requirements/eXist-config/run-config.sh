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

new_port="8868"
set_sysuser="false"
del_autodeploy="false"
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


# Use regex and XSLT to make changes to config files.
if [ $new_port != "8080" ]; then
  echo "Configuring eXist to use port $new_port"
  mv $EXIST_HOME/tools/jetty/etc/jetty.xml $EXIST_HOME/tools/jetty/etc/jetty.xml.orig
  sed "s/8080/$new_port/g" $EXIST_HOME/tools/jetty/etc/jetty.xml.orig > $EXIST_HOME/tools/jetty/etc/jetty.xml
  # Use updated port numbers for the Java Admin Client.
  sed -E "s/8080/$new_port/g" $EXIST_HOME/client.properties.tmpl > $EXIST_HOME/client.properties
  # Use updated port numbers for backups.
  mv $EXIST_HOME/backup.properties $EXIST_HOME/backup.properties.tmpl
  sed -E "s/8080/$new_port/g" $EXIST_HOME/backup.properties.tmpl > $EXIST_HOME/backup.properties
fi
# Increase maximum form content size from 200000 to 600000.
echo "Increasing maximum form content size"
cp $DIR/jetty-web.xml $EXIST_HOME/webapps/WEB-INF/jetty-web.xml
echo "Running configuration stylesheets"
# Configure startup and database options.
mv $EXIST_HOME/conf.xml $EXIST_HOME/conf.xml.orig
java -jar $EXIST_HOME/lib/endorsed/saxonhe*.jar -s:$EXIST_HOME/conf.xml.orig -xsl:$DIR/startup-and-db-config.xsl -o:$EXIST_HOME/conf.xml
# Disable URL forwarding to unneeded servlets.
mv $EXIST_HOME/webapp/WEB-INF/controller-config.xml $EXIST_HOME/webapp/WEB-INF/controller-config.xml.orig
java -jar $EXIST_HOME/lib/endorsed/saxonhe*.jar -s:$EXIST_HOME/webapp/WEB-INF/controller-config.xml.orig -xsl:$DIR/network-servlet-management.xsl -o:$EXIST_HOME/webapp/WEB-INF/controller-config.xml
# Disable unneeded network servlets.
mv $EXIST_HOME/webapp/WEB-INF/web.xml $EXIST_HOME/webapp/WEB-INF/web.xml.orig
java -jar $EXIST_HOME/lib/endorsed/saxonhe*.jar -s:$EXIST_HOME/webapp/WEB-INF/web.xml.orig -xsl:$DIR/network-servlet-management.xsl -o:$EXIST_HOME/webapp/WEB-INF/web.xml
# Generalize the Java path that the service wrapper wants to use.
mv $EXIST_HOME/tools/wrapper/conf/wrapper.conf $EXIST_HOME/tools/wrapper/conf/wrapper.conf.orig
sed -E "s/\/usr\/lib\/jvm\/java.*\/jre(\/bin\/java)$/\/etc\/alternatives\/jre\1/g" $EXIST_HOME/tools/wrapper/conf/wrapper.conf.orig > $EXIST_HOME/tools/wrapper/conf/wrapper.conf

# Normally, eXist will automatically deploy any apps in the 'autodeploy' folder 
#  on the server. A script has already disabled this functionality, but now we
#  need to make sure that the folder is renamed, if not removed.
#if [ $del_autodeploy == "false" ]; then
#  mv $EXIST_HOME/autodeploy/ $EXIST_HOME/non-autodeploy
#else
#  rm -R $EXIST_HOME/autodeploy/
#fi

# Give an eXist-specific user ownership over $EXIST_HOME and running the service.
if [ $set_sysuser == "true" ]; then
  grep --silent "existdb" /etc/passwd
  if [ $? == 1 ]; then 
    echo "Adding a system user account for eXist"
    sudo useradd -U existdb
  fi
  echo "Giving ownership of $EXIST_HOME to user 'existdb'"
  mv $EXIST_HOME/tools/wrapper/bin/exist.sh $EXIST_HOME/tools/wrapper/bin/exist.sh.orig
  sed -E "s/^#(RUN_AS_USER=)$/\1existdb/g" $EXIST_HOME/tools/wrapper/bin/exist.sh.orig > $EXIST_HOME/tools/wrapper/bin/exist.sh
  sudo chown -R existdb:existdb $EXIST_HOME/
fi
sudo chmod -R --preserve-root 775 $EXIST_HOME
# Make eXist a service, using a built-in script.
echo "Setting up eXist as a service"
if [ -f /etc/init.d/existdb ]; then
	if [ -h /etc/init.d/existdb ]; then
		sudo ln -s -f $EXIST_HOME/tools/wrapper/bin/exist.sh /etc/init.d/existdb
	else
		echo "/etc/init.d/existdb points at an actual file.  Aborting!"
	fi
else
	sudo ln -s $EXIST_HOME/tools/wrapper/bin/exist.sh /etc/init.d/existdb
fi
echo "Configuring eXist to start on boot"
sudo chkconfig --add existdb
