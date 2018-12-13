
<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import href="website-l10n.xsl"/>

  <!-- book versions -->
  <xsl:param name="local.book.version">test build</xsl:param>
  <xsl:param name="local.book.multi_version" select="0"/>
  <xsl:param name="local.page.header"></xsl:param>
  <xsl:param name="local.book.section.title">Learn/Docs/</xsl:param>
  <xsl:param name="local.book.subject"></xsl:param>
  <xsl:param name="local.book.version"></xsl:param>


  <!-- header -->
  <xsl:param name="local.noindex" select="''"/>

  <!-- css -->
  <xsl:param name="generate.consistent.ids" select="1"/>
  <xsl:param name="css.decoration"          select="0"/>
  <xsl:param name="html.stylesheet"></xsl:param>

  <!-- nav -->
  <xsl:param name="part.autolabel"          select="0"/>
  <xsl:param name="chapter.autolabel"       select="0"/>
  <xsl:param name="section.autolabel"       select="0"/>

  <!-- layout -->
  <xsl:param name="table.borders.with.css"  select="0"/>
  <xsl:param name="highlight.source"        select="1"/>

  <xsl:param name="generate.toc"></xsl:param>
  <xsl:param name="toc.list.type"           select="'ul'"/>

  <!-- meta elements -->
  <xsl:template name="user.head.content">
    <xsl:variable name="meta-description">
      <xsl:call-template name="gentext.template">
        <xsl:with-param name="context" select="'meta'"/>
        <xsl:with-param name="name" select="'meta-description'"/>
      </xsl:call-template>
    </xsl:variable>

    <meta name="description" content="{$meta-description}" />
    <meta name="DC.type">
      <xsl:attribute name="content">
        <xsl:value-of select="$local.book.section.title" />
      </xsl:attribute>
    </meta>
    <meta name="DC.subject">
      <xsl:attribute name="content">
        <xsl:value-of select="$local.book.subject" />
      </xsl:attribute>
    </meta>
    <meta name="DC.identifier">
      <xsl:attribute name="content">
        <xsl:value-of select="$local.book.version" />
      </xsl:attribute>
    </meta>
    <xsl:if test="$local.noindex!=''">
      <meta name="robots" content="noindex,nofollow" />
    </xsl:if>
  </xsl:template>

  <!--  title element -->
  <xsl:template name="user.head.title">
    <xsl:param name="node" select="."/>
    <xsl:param name="title"/>
    <xsl:variable name="home" select="/*[1]"/>

    <title>
      <xsl:copy-of select="$title"/>
      <xsl:if test="$node != $home">
        | <xsl:apply-templates select="$home" mode="object.title.markup.textonly"/>
      </xsl:if>
      | Elastic
    </title>
  </xsl:template>

  <!-- Edit me links -->

  <xsl:template match="ulink[@role='edit_me']">
    <xsl:variable name="title">
      <xsl:call-template name="gentext.template">
        <xsl:with-param name="context" select="'edit-me'"/>
        <xsl:with-param name="name" select="'edit-me-title'"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="text">
      <xsl:call-template name="gentext.template">
        <xsl:with-param name="context" select="'edit-me'"/>
        <xsl:with-param name="name" select="'edit-me-text'"/>
      </xsl:call-template>
    </xsl:variable>
    <a href="{attribute::url}" class="edit_me" title="{$title}" rel="nofollow"><xsl:value-of select="$text" /></a>
  </xsl:template>

  <xsl:template match="ulink[@role='edit_me']" mode="no.anchor.mode" />

 <!--  head title element with version -->

    <xsl:template name="user.header.content">
      <xsl:if test="$local.page.header!=''">
        <div class="page_header">
          <xsl:value-of select="$local.page.header" disable-output-escaping="yes"/>
        </div>
      </xsl:if>

        <xsl:if test="$local.book.multi_version &gt; 0">
          <p>
             These docs are for branch: <xsl:value-of select="$local.book.version" />.
             <a href="../index.html">Other versions</a>.
          </p>
        </xsl:if>
    </xsl:template>

  <!-- add prettyprint classes to code blocks -->
  <xsl:template match="programlisting" mode="common.html.attributes">
    <xsl:param name="class">
      <xsl:value-of select="local-name(.)" />
      <xsl:if test="@language != ''"> prettyprint lang-<xsl:value-of select="@language" /></xsl:if>
    </xsl:param>
    <xsl:param name="inherit" select="0"/>
    <xsl:call-template name="generate.html.lang"/>
    <xsl:call-template name="dir">
      <xsl:with-param name="inherit" select="$inherit"/>
    </xsl:call-template>
    <xsl:apply-templates select="." mode="class.attribute">
      <xsl:with-param name="class" select="$class"/>
    </xsl:apply-templates>
    <xsl:call-template name="generate.html.title"/>
  </xsl:template>

  <xsl:template match="programlisting">
    <div class="pre_wrapper">
        <xsl:apply-imports />
    </div>
  </xsl:template>

  <!-- Make callouts non-selectable -->
  <xsl:template name="callout-bug">
    <xsl:param name="conum" select="1"/>
    <span><img src="{$callout.graphics.path}{$conum}{$callout.graphics.extension}" alt="" /></span>
  </xsl:template>

  <!-- added and deprecated markup -->
  <xsl:template match="phrase[@revisionflag]">
    <xsl:variable name="classname">
      <xsl:choose>
        <xsl:when test="attribute::revisionflag='added'">added</xsl:when>
        <xsl:when test="attribute::revisionflag='changed'">coming</xsl:when>
        <xsl:when test="attribute::revisionflag='deleted'">deprecated</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <span class="{$classname}">
      [<span class="version"><xsl:value-of select="attribute::revision" /></span>]
      <span class="detail">
        <xsl:call-template name="revision-text" />
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

  <!--  Sentence for Added/Coming/Deprecated in ... -->
  <xsl:template name="revision-text">
    <xsl:variable name="type">
      <xsl:choose>
        <xsl:when test="attribute::revisionflag='added'">added</xsl:when>
        <xsl:when test="attribute::revisionflag='changed'">coming</xsl:when>
        <xsl:when test="attribute::revisionflag='deleted'">deprecated</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:call-template name="gentext.template">
      <xsl:with-param name="context" select="'annotation'"/>
      <xsl:with-param name="name" select="$type"/>
    </xsl:call-template>
    <xsl:value-of select="attribute::revision" />
    <xsl:call-template name="gentext.template">
      <xsl:with-param name="context" select="'annotation'"/>
      <xsl:with-param name="name" select="'sentence-separator'"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Inline experimental/beta -->
  <xsl:template match="phrase[@role='experimental']|phrase[@role='beta']">
    <xsl:variable name="classname" select="attribute::role" />
    <span class="{$classname}">
      [<span class="{$classname}_title">
        <xsl:call-template name="experimental-beta-title" />
      </span>]
      <span class="detail">
        <xsl:call-template name="experimental-beta-text" />
      </span>
    </span>
  </xsl:template>

  <xsl:template name="experimental-beta-title">
    <xsl:call-template name="gentext.template">
      <xsl:with-param name="context" select="'annotation'"/>
      <xsl:with-param name="name" select="attribute::role"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="experimental-beta-text">
    <xsl:variable name="text">
      <xsl:apply-templates />
    </xsl:variable>
    <xsl:choose>
        <xsl:when test="normalize-space($text) != ''">
            <xsl:value-of select="$text" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="gentext.template">
            <xsl:with-param name="context" select="'annotation'"/>
            <xsl:with-param name="name" select="concat(attribute::role,'-text')"/>
          </xsl:call-template>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Don't display in ToC -->
  <xsl:template match="phrase" mode="no.anchor.mode" />
  <xsl:template match="part[@role='exclude']
                      |appendix[@role='exclude']
                      |chapter[@role='exclude']
                      |section[@role='exclude']
                      |sect1[@role='exclude']"  mode="toc" />

  <!--  Annotations NOTE/WARNING/etc -->
  <xsl:template name="graphical.admonition">
      <xsl:variable name="admon.type">
        <xsl:choose>
          <xsl:when test="local-name(.)='note'">Note</xsl:when>
          <xsl:when test="local-name(.)='warning'">Warning</xsl:when>
          <xsl:when test="local-name(.)='caution'">Caution</xsl:when>
          <xsl:when test="local-name(.)='tip'">Tip</xsl:when>
          <xsl:when test="local-name(.)='important'">Important</xsl:when>
          <xsl:otherwise>Note</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="alt">
        <xsl:call-template name="gentext">
          <xsl:with-param name="key" select="$admon.type"/>
        </xsl:call-template>
      </xsl:variable>

      <div class="{local-name(.)} admon">
        <xsl:call-template name="id.attribute"/>

        <div class="icon">
            <img alt="{$alt}">
                <xsl:attribute name="src">
                  <xsl:call-template name="admon.graphic"/>
                </xsl:attribute>
            </img>
        </div>
        <div class="admon_content">
          <xsl:choose>
            <xsl:when test="attribute::revisionflag != ''">
              <xsl:call-template name="graphical.admonition.revision.content" />
            </xsl:when>
            <xsl:when test="attribute::role = 'experimental' or attribute::role = 'beta'">
              <xsl:call-template name="graphical.admonition.experimental.content" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="graphical.admonition.standard.content" />
            </xsl:otherwise>
          </xsl:choose>
        </div>
      </div>
    </xsl:template>

    <!-- Block added/coming/deprecated -->
    <xsl:template name="graphical.admonition.revision.content">
      <xsl:variable name="revision_text">
        <xsl:call-template name="revision-text" />
      </xsl:variable>
      <xsl:variable name="content">
        <xsl:apply-templates/>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="normalize-space($content) = ''">
            <p>
              <xsl:value-of select="$revision_text" />
            </p>
        </xsl:when>
        <xsl:otherwise>
            <h3>
              <xsl:value-of select="$revision_text" />
            </h3>
            <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <!-- Block experimental/beta -->
    <xsl:template name="graphical.admonition.experimental.content">
      <xsl:variable name="content">
        <xsl:apply-templates />
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="normalize-space($content) = ''">
            <p>
              <xsl:call-template name="gentext.template">
                <xsl:with-param name="context" select="'annotation'"/>
                <xsl:with-param name="name" select="concat(attribute::role,'-text')"/>
              </xsl:call-template>
            </p>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <!--  Standard admonition content -->
    <xsl:template name="graphical.admonition.standard.content">
      <xsl:choose>
        <xsl:when test="$admon.textlabel != 0 or title or info/title">
          <h3>
            <xsl:apply-templates select="." mode="object.title.markup"/>
            <xsl:call-template name="anchor"/>
          </h3>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="anchor"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates/>
    </xsl:template>

    <!-- Sense widget -->
    <xsl:template match="remark[parent::answer|parent::appendix|parent::article|parent::bibliodiv|                                 parent::bibliography|parent::blockquote|parent::caution|parent::chapter|                                 parent::glossary|parent::glossdiv|parent::important|parent::index|                                 parent::indexdiv|parent::listitem|parent::note|parent::orderedlist|                                 parent::partintro|parent::preface|parent::procedure|parent::qandadiv|                                 parent::qandaset|parent::question|parent::refentry|parent::refnamediv|                                 parent::refsect1|parent::refsect2|parent::refsect3|parent::refsection|                                 parent::refsynopsisdiv|parent::sect1|parent::sect2|parent::sect3|parent::sect4|                                 parent::sect5|parent::section|parent::setindex|parent::sidebar|                                 parent::simplesect|parent::taskprerequisites|parent::taskrelated|                                 parent::tasksummary|parent::warning|parent::topic]">
      <xsl:if test="$show.comments != 0">
        <xsl:choose>
        <xsl:when test="contains(text(),'AUTOSENSE')">
            <div class="sense_widget" data-snippet=":AUTOSENSE:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'CONSOLE') and not(contains(text(),'NOTCONSOLE'))">
            <div class="console_widget" data-snippet=":CONSOLE:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'KIBANA')">
            <div class="kibana_widget" data-snippet=":KIBANA:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'SENSE:')">
            <xsl:variable name="sense_url" select="translate(substring-after(text(),'SENSE:'),' ','')" />
            <div class="sense_widget" data-snippet="snippets/{$sense_url}"></div>
        </xsl:when>
        </xsl:choose>

      </xsl:if>
    </xsl:template>

    <xsl:template match="comment|remark">
      <xsl:if test="$show.comments != 0">
        <xsl:choose>
        <xsl:when test="contains(text(),'AUTOSENSE')">
            <div class="sense_widget" data-snippet=":AUTOSENSE:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'CONSOLE') and not(contains(text(),'NOTCONSOLE'))">
            <div class="console_widget" data-snippet=":CONSOLE:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'KIBANA')">
            <div class="kibana_widget" data-snippet=":KIBANA:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'SENSE:')">
            <xsl:variable name="sense_url" select="translate(substring-after(text(),'SENSE:'),' ','')" />
            <div class="sense_widget" data-snippet="snippets/{$sense_url}"></div>
        </xsl:when>
        </xsl:choose>
      </xsl:if>
    </xsl:template>

    <!--  Add classes to images -->

    <xsl:template match="*" mode="class.value">
      <xsl:param name="class">
        <xsl:value-of select="local-name(.)" />
      </xsl:param>
      <xsl:if test="@role">
        <xsl:value-of select="@role"/>
        <xsl:value-of select="' '"/>
      </xsl:if>
      <xsl:value-of select="$class" />
    </xsl:template>

</xsl:stylesheet>
