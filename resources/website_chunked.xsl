<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import href="website.xsl"/>
  <xsl:import href="asciidoc-8.6.8/docbook-xsl/chunked.xsl"/>
  <xsl:import href="website_common.xsl"/>

  <!-- chunking options -->
  <xsl:param name="use.id.as.filename"       select="1"/>
  <xsl:param name="chunk.quietly"            select="1"/>
  <xsl:param name="chunker.output.encoding"  select="'UTF-8'"/>
  <xsl:param name="chunker.output.omit-xml-declaration">no</xsl:param>

  <!-- toc -->
  <xsl:param name="generate.section.toc.level"  select="chunk.section.depth"/>
  <xsl:param name="toc.section.depth"           select="chunk.section.depth"/>
  <xsl:param name="toc.max.depth"               select="5"/>

  <xsl:param name="generate.toc">
    book      toc
  </xsl:param>

  <xsl:template name="user.header.content" />

  <!-- Page header -->
  <xsl:template match="processing-instruction('page_header')"/>
  <xsl:template name="page.header">
    <xsl:variable name="page.header">
      <xsl:value-of select="normalize-space(preceding::processing-instruction('page_header')[1])"/>
    </xsl:variable>
    <xsl:if test="$page.header!=''">
      <div class="page_header">
        <xsl:value-of select="$page.header" disable-output-escaping="yes"/>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- Generate ToC for book and parts -->
  <xsl:template name="division.toc">
    <xsl:param name="toc-context" select="."/>
    <xsl:param name="toc.title.p" select="false()"/>
    <xsl:param name="local.check.multi" select="true()" />

    <xsl:comment>START_TOC</xsl:comment>
    <xsl:for-each select="self::book | ancestor::book">
        <xsl:call-template name="make.toc">
          <xsl:with-param name="toc-context" select="."/>
          <xsl:with-param name="toc.title.p" select="$toc.title.p"/>
          <xsl:with-param name="nodes" select="part|reference                                          |preface|chapter|appendix                                          |article                                          |topic                                          |bibliography|glossary|index                                          |refentry                                          |bridgehead[$bridgehead.in.toc != 0]"/>
        </xsl:call-template>
    </xsl:for-each>
    <xsl:comment>END_TOC</xsl:comment>

  </xsl:template>

  <!-- added and deprecated markup -->
  <xsl:template match="phrase[@revisionflag='added']" mode="toc" />
  <xsl:template match="phrase[@revisionflag='changed']" mode="toc" />
  <xsl:template match="phrase[@revisionflag='deleted']" mode="toc" />
  <xsl:template match="phrase[@role='experimental']" mode="toc" />


  <!-- generate book-level toc for all chapters -->
  <xsl:template name="component.toc" />

  <!-- generate book-level toc for all top-level sections -->
  <xsl:template name="section.toc" />


  <!-- breadcrumbs -->
  <xsl:template name="breadcrumbs">
    <xsl:param name="this.node" select="."/>
    <xsl:if test="local-name(.) != 'book'">
      <div class="breadcrumbs">
        <xsl:for-each select="$this.node/ancestor::*">
          <span class="breadcrumb-link">
            <a>
              <xsl:attribute name="href">
                <xsl:call-template name="href.target">
                  <xsl:with-param name="object" select="."/>
                  <xsl:with-param name="context" select="$this.node"/>
                </xsl:call-template>
              </xsl:attribute>
              <xsl:apply-templates select="." mode="title.markup"/>
            </a>
          </span>
          <xsl:text> » </xsl:text>
        </xsl:for-each>
        <!-- And display the current node, but not as a link -->
        <span class="breadcrumb-node">
          <xsl:apply-templates select="$this.node" mode="title.markup"/>
        </span>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- include the book version in the breadcrumbs -->
  <xsl:template match="book" mode="title.markup">
    <xsl:param name="allow-anchors" select="0"/>
    <xsl:apply-templates select="(bookinfo/title|info/title|title)[1]"
                         mode="title.markup">
      <xsl:with-param name="allow-anchors" select="$allow-anchors"/>
    </xsl:apply-templates>
    <xsl:if test="$local.book.multi_version &gt; 0">
      [<xsl:value-of select="$local.book.version" />]
    </xsl:if>
  </xsl:template>

  <!-- navigation -->
  <xsl:template name="header.navigation">
    <xsl:param name="prev" />
    <xsl:param name="next" />
    <xsl:param name="nav.context"/>
    <xsl:call-template name="page.header" />
    <xsl:if test="$nav.context != 'toc'">
      <xsl:call-template name="breadcrumbs"/>
    </xsl:if>
    <xsl:call-template name="custom.navigation">
      <xsl:with-param name="nav.class"   select="'navheader'" />
      <xsl:with-param name="prev"        select="$prev" />
      <xsl:with-param name="next"        select="$next" />
      <xsl:with-param name="nav.context" select="$nav.context" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="footer.navigation">
    <xsl:param name="prev" />
    <xsl:param name="next" />
    <xsl:param name="nav.context"/>
    <xsl:call-template name="custom.navigation">
      <xsl:with-param name="nav.class"   select="'navfooter'" />
      <xsl:with-param name="prev"        select="$prev" />
      <xsl:with-param name="next"        select="$next" />
      <xsl:with-param name="nav.context" select="$nav.context" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="custom.navigation">
    <xsl:param name="prev" select="/foo"/>
    <xsl:param name="next" select="/foo"/>
    <xsl:param name="nav.class"  />
    <xsl:param name="nav.context"/>

    <xsl:variable name="row" select="count($prev) &gt; 0
                                      or count($next) &gt; 0"/>
    <xsl:variable name="home" select="/*[1]"/>

    <div>
      <xsl:attribute name="class">
        <xsl:value-of select="$nav.class" />
      </xsl:attribute>
      <xsl:if test="$row">
        <span class="prev">
          <xsl:if test="count($prev)>0 and generate-id($home) != generate-id($prev)">
            <a>
              <xsl:attribute name="href">
                <xsl:call-template name="href.target">
                  <xsl:with-param name="object" select="$prev"/>
                </xsl:call-template>
              </xsl:attribute>
              &#171;&#160;
              <xsl:apply-templates select="$prev" mode="object.title.markup"/>
            </a>
          </xsl:if>
          &#160;
        </span>
        <span class="next">
          &#160;
          <xsl:if test="count($next)>0">
            <a>
              <xsl:attribute name="href">
                <xsl:call-template name="href.target">
                  <xsl:with-param name="object" select="$next"/>
                </xsl:call-template>
              </xsl:attribute>
              <xsl:apply-templates select="$next" mode="object.title.markup"/>
              &#160;&#187;
            </a>
          </xsl:if>
        </span>
      </xsl:if>
    </div>
  </xsl:template>

</xsl:stylesheet>

