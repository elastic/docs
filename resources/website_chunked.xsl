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
  <xsl:param name="generate.section.toc.level"  select="$chunk.section.depth"/>
  <xsl:param name="toc.section.depth"           select="$chunk.section.depth"/>
  <xsl:param name="toc.max.depth"               select="1"/>
  <xsl:param name="generate.toc">
    book      toc
    chapter   toc
    part      toc
    section   toc
  </xsl:param>

  <!-- Include link to other versions on the homepage ToC -->
    <xsl:template name="user.header.content" />

  <xsl:template name="division.toc">
    <xsl:param name="toc-context" select="."/>
    <xsl:param name="toc.title.p" select="true()"/>
    <xsl:param name="local.check.multi" select="true()" />

    <xsl:call-template name="make.toc">
      <xsl:with-param name="toc-context" select="$toc-context"/>
      <xsl:with-param name="toc.title.p" select="$toc.title.p"/>
      <xsl:with-param name="nodes" select="part|reference                                          |preface|chapter|appendix                                          |article                                          |topic                                          |bibliography|glossary|index                                          |refentry                                          |bridgehead[$bridgehead.in.toc != 0]"/>

    </xsl:call-template>
    <xsl:if test="$local.check.multi">
      <xsl:if test="local-name(.)='book'">
        <xsl:if test="$local.book.multi_version &gt; 0">
          <p>
             These docs are for branch: <xsl:value-of select="$local.book.version" />.
             <a href="../index.html">Other versions</a>.
          </p>
        </xsl:if>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- generate part-level toc if chapter has no descendants -->
  <xsl:template name="component.toc">
    <xsl:param name="toc-context" select="."/>

    <xsl:variable name="nodes" select="section|sect1
                                           |simplesect[$simplesect.in.toc != 0]
                                           |refentry
                                           |article|bibliography|glossary
                                           |appendix|index
                                           |bridgehead[not(@renderas)
                                                       and $bridgehead.in.toc != 0]
                                           |.//bridgehead[@renderas='sect1'
                                                          and $bridgehead.in.toc != 0]"/>
    <xsl:choose>
      <xsl:when test="count($nodes) &lt; 2 or $chunk.section.depth = 0">
        <xsl:for-each select="parent::book | parent::part">
          <xsl:call-template name="division.toc">
            <xsl:with-param name="toc-context" select="." />
            <xsl:with-param name="local.check.multi" select="false()" />
          </xsl:call-template>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="make.toc">
          <xsl:with-param name="toc-context" select="$toc-context"/>
          <xsl:with-param name="nodes" select="$nodes"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- generate chapter-level toc for all top-level sections -->
  <xsl:template name="section.toc">
    <xsl:for-each select="parent::chapter">
      <xsl:call-template name="component.toc">
        <xsl:with-param name="toc-context" select="." />
      </xsl:call-template>
    </xsl:for-each>
  </xsl:template>

<xsl:template match="preface|chapter|appendix|article" mode="toc">
  <xsl:param name="toc-context" select="."/>

  <xsl:choose>
    <xsl:when test="local-name($toc-context) = 'book'">
      <xsl:call-template name="subtoc">
        <xsl:with-param name="toc-context" select="$toc-context"/>
        <xsl:with-param name="nodes"
              select="section|sect1|glossary|bibliography|index
                     |bridgehead[$bridgehead.in.toc != 0]"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="subtoc">
        <xsl:with-param name="toc-context" select="$toc-context"/>
        <xsl:with-param name="nodes" select="foo"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

  <xsl:template match="part[@role='exclude']
                      |appendix[@role='exclude']
                      |chapter[@role='exclude']
                      |section[@role='exclude']
                      |sect1[@role='exclude']"  mode="toc" />

  <!--  Display part-level TOC before the partintro -->
    <xsl:template match="partintro">
      <xsl:call-template name="id.warning"/>

      <div>
        <xsl:call-template name="common.html.attributes"/>
        <xsl:call-template name="id.attribute">
          <xsl:with-param name="conditional" select="0"/>
        </xsl:call-template>

        <xsl:call-template name="partintro.titlepage"/>

        <xsl:variable name="toc.params">
          <xsl:call-template name="find.path.params">
            <xsl:with-param name="node" select="parent::*"/>
            <xsl:with-param name="table" select="normalize-space($generate.toc)"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:if test="contains($toc.params, 'toc')">
          <!-- not ancestor::part because partintro appears in reference -->
          <xsl:apply-templates select="parent::*" mode="make.part.toc"/>
        </xsl:if>
        <xsl:apply-templates/>
        <xsl:call-template name="process.footnotes"/>
      </div>
    </xsl:template>

  <!-- Disable the TOC title -->
  <xsl:template name="make.toc">
    <xsl:param name="toc-context" select="."/>
    <xsl:param name="nodes" select="/NOT-AN-ELEMENT"/>
    <xsl:if test="$nodes">
      <div class="toc">
        <xsl:element name="{$toc.list.type}">
          <xsl:apply-templates select="$nodes" mode="toc">
            <xsl:with-param name="toc-context" select="$toc-context"/>
          </xsl:apply-templates>
        </xsl:element>
      </div>
    </xsl:if>
  </xsl:template>

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

