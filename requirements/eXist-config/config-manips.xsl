<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0">
  <!-- Templates for common XML manipulation.                               -->
  <!--   last modified: May 2015                                            -->
  <!--   author: Ashley M. Clark                                            -->
  
  <xsl:template match="/" mode="#all">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="*" mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="text() | @*" mode="#all">
    <xsl:copy/>
  </xsl:template>
  
  <xsl:template match="comment()" mode="#default">
    <xsl:copy/>
  </xsl:template>
  
  <!--  COMMENTS  -->
  
  <!-- If a comment is primed to gain an ancestor comment, make it a fake 
    comment a la oXygen. -->
  <xsl:template match="comment()" mode="escape">
    <xsl:text disable-output-escaping="yes">&lt;!-\-</xsl:text>
    <xsl:value-of select="."/>
    <xsl:text disable-output-escaping="yes">-\-&gt;</xsl:text>
  </xsl:template>
  
  <!-- Place a comment around some XML. -->
  <xsl:template name="commentOut">
    <xsl:param name="unwantedNode" required="yes"/>
    <xsl:variable name="escapedNode">
      <xsl:copy>
        <xsl:apply-templates select="@* | node()" mode="escape"/>
      </xsl:copy>
    </xsl:variable>
    
    <xsl:text disable-output-escaping="yes">&lt;!--</xsl:text>
    <xsl:copy-of select="$escapedNode"/>
    <xsl:text disable-output-escaping="yes">--&gt;</xsl:text>
  </xsl:template>
  
  <!-- Remove some XML from a comment. -->
  <!-- Note that this template may not be useful for nested comments! -->
  <xsl:template name="outComment">
    <xsl:param name="comment" required="yes" as="xs:string"/>
    
    <xsl:value-of disable-output-escaping="yes" select="$comment"/>
  </xsl:template>
</xsl:stylesheet>