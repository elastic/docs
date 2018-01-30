<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text"/>

  <xsl:template match="text()">
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template match="article">
    <xsl:for-each select="descendant::*[@id]">
        <xsl:value-of select="attribute::id" />
        <xsl:text>&#10;</xsl:text>
        <xsl:apply-templates />
    </xsl:for-each>
  </xsl:template>


</xsl:stylesheet>

