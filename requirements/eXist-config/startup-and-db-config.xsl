<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  exclude-result-prefixes="xs" version="2.0">

  <xsl:output indent="yes"/>

  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="*">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="comment() | text() | @*">
    <xsl:copy/>
  </xsl:template>
  
  <xsl:template
    match="startup//trigger[@class='org.exist.extensions.exquery.restxq.impl.RestXqStartupTrigger' 
                                        or @class='org.exist.repo.AutoDeploymentTrigger']">
    <xsl:call-template name="commentOut">
      <xsl:with-param name="unwantedElement">
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <xsl:apply-templates/>
        </xsl:copy>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="indexer">
    <xsl:copy>
      <xsl:attribute name="preserve-whitespace-mixed-content">yes</xsl:attribute>
      <xsl:attribute name="stemming">yes</xsl:attribute>
      <xsl:apply-templates select="@*[not(local-name()='preserve-whitespace-mixed-content' or local-name()='stemming')]"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="comment()[contains(.,'databackup')]">
    <xsl:call-template name="outComment">
      <xsl:with-param name="comment" as="xs:string">
        <!-- Need to replace the backup time as well! -->
        <xsl:copy/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <!-- Place a comment around some XML. -->
  <xsl:template name="commentOut">
    <xsl:param name="unwantedElement" required="yes"/>
    
    <xsl:text disable-output-escaping="yes">&lt;!-- </xsl:text>
    <xsl:copy-of select="$unwantedElement"/>
    <xsl:text disable-output-escaping="yes"> --&gt;</xsl:text>
  </xsl:template>
  
  <!-- Remove some XML from a comment. -->
  <xsl:template name="outComment">
    <xsl:param name="comment" required="yes" as="xs:string"/>
    
    <xsl:value-of select="replace(replace($comment,'&lt;!--',''),'--&gt;','')" disable-output-escaping="yes"/>
  </xsl:template>
</xsl:stylesheet>
