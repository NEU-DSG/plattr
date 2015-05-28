<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="xs" version="2.0">
  <!-- Configure eXist's startup and database behaviors.                    -->
  <!-- For use on:                                                          -->
  <!--        $EXIST_HOME/conf.xml                                          -->
  <!--   last modified: May 2015                                            -->
  <!--   author: Ashley M. Clark                                            -->
  
  <xsl:import href="config-manips.xsl"/>
  <xsl:output indent="yes"/>
  
  <xsl:template
    match="startup//trigger[@class='org.exist.extensions.exquery.restxq.impl.RestXqStartupTrigger' or 
                            @class='org.exist.repo.AutoDeploymentTrigger']">
    <xsl:call-template name="commentOut">
      <xsl:with-param name="unwantedNode">
        <xsl:copy>
          <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="indexer/@preserve-whitespace-mixed-content">
    <xsl:attribute name="preserve-whitespace-mixed-content">yes</xsl:attribute>
  </xsl:template>
  
  <xsl:template match="indexer/@stemming">
    <xsl:attribute name="stemming">yes</xsl:attribute>
  </xsl:template>
  
  <!-- Uncomment the auto-backup task and trigger it every 3 days. -->
  <xsl:template match="comment()[contains(.,'databackup')]">
    <xsl:variable name="backupEvery" as="xs:string">259200000</xsl:variable> <!-- in milliseconds -->
    <xsl:call-template name="outComment">
      <xsl:with-param name="comment" as="xs:string">
        <xsl:value-of select="replace(.,'(period=&quot;)\d+(&quot;)',concat('$1',$backupEvery,'$2'))"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="serializer/@enable-xsl">
    <xsl:attribute name="enable-xsl">yes</xsl:attribute>
  </xsl:template>
  
  <xsl:template match="builtin-modules/module[@uri='http://exist-db.org/xquery/examples' or
                                              @uri='http://exist-db.org/xquery/mail'  or
                                              @uri='http://exquery.org/ns/restxq' or
                                              @uri='http://exquery.org/ns/restxq/exist' or
                                              @uri='http://exist-db.org/xquery/xslfo']">
    <xsl:call-template name="commentOut">
      <xsl:with-param name="unwantedNode">
        <xsl:copy>
          <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <!-- Disable util:eval functions. -->
  <xsl:template match="builtin-modules/module[@uri='http://exist-db.org/xquery/util']/parameter[@name='evalDisabled']/@value">
    <xsl:attribute name="value">true</xsl:attribute>
  </xsl:template>
  
</xsl:stylesheet>
