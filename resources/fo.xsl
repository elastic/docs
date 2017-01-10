<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:fo="http://www.w3.org/1999/XSL/Format">

  <xsl:import href="asciidoc-8.6.8/docbook-xsl/fo.xsl"/>
  <xsl:import href="fo_titlepage.xsl" />

  <!-- Fonts and font-sizes -->
  <xsl:param name="body.font.family" >Helvetica</xsl:param>
  <xsl:param name="body.font.master" select="10" />

  <xsl:attribute-set name="section.title.level1.properties">
    <xsl:attribute name="font-size">
      <xsl:value-of select="$body.font.master * 1.3"/>
      <xsl:text>pt</xsl:text>
    </xsl:attribute>
    <xsl:attribute name="color">#2b4590</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="section.title.level2.properties">
    <xsl:attribute name="font-size">
      <xsl:value-of select="$body.font.master * 1.2"/>
      <xsl:text>pt</xsl:text>
    </xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="section.title.level3.properties">
    <xsl:attribute name="font-size">
      <xsl:value-of select="$body.font.master * 1.1"/>
      <xsl:text>pt</xsl:text>
    </xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="section.title.level4.properties">
    <xsl:attribute name="font-size">
      <xsl:value-of select="$body.font.master"/>
      <xsl:text>pt</xsl:text>
    </xsl:attribute>
  </xsl:attribute-set>

  <!-- Code blocks -->
  <xsl:attribute-set name="shade.verbatim.style">
    <xsl:attribute name="padding-left">12pt</xsl:attribute>
    <xsl:attribute name="padding-right">12pt</xsl:attribute>
    <xsl:attribute name="padding-top">6pt</xsl:attribute>
    <xsl:attribute name="padding-bottom">6pt</xsl:attribute>
    <xsl:attribute name="background-color">#EEEEEE</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="monospace.verbatim.properties">
      <xsl:attribute name="wrap-option">wrap</xsl:attribute>
      <xsl:attribute name="border">none</xsl:attribute>
  </xsl:attribute-set>

  <!-- ToC -->
  <xsl:param name="bridgehead.in.toc" select="1"/>
  <xsl:param name="section.autolabel" select="0" />
  <xsl:param name="section.label.includes.component.label" select="0"></xsl:param>

  <!-- Links -->
  <xsl:attribute-set name="xref.properties">
    <xsl:attribute name="color">#31beb1</xsl:attribute>
  </xsl:attribute-set>

  <!-- Disable edit-me links -->
  <xsl:template match="ulink[@role='edit_me']" />
  <xsl:template match="ulink[@role='edit_me']" mode="no.anchor.mode" />

  <!-- added and deprecated markup -->
  <xsl:template match="phrase[@revisionflag='added']">
    <fo:inline font-style="italic">[<xsl:apply-templates />]</fo:inline>
  </xsl:template>

  <xsl:template match="phrase[@revisionflag='changed']">
    <fo:inline font-style="italic">[<xsl:apply-templates />]</fo:inline>
  </xsl:template>

  <xsl:template match="phrase[@revisionflag='deleted']">
    <fo:inline font-style="italic">[<xsl:apply-templates />]</fo:inline>
  </xsl:template>

  <xsl:template match="phrase[@role='experimental']">
    <fo:inline font-style="italic">[<xsl:apply-templates />]</fo:inline>
  </xsl:template>

  <!-- Don't display in ToC -->
  <xsl:template match="phrase" mode="no.anchor.mode" />

</xsl:stylesheet>

