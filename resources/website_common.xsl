<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!-- github repo info -->
  <xsl:param name="local.root" select="0" />
  <xsl:param name="local.repo" select="0" />
  <xsl:param name="local.edit_url" select="0" />
  <xsl:param name="local.comments" select="0" />

  <!-- book versions -->
  <xsl:param name="local.book.version">test build</xsl:param>
  <xsl:param name="local.book.multi_version" select="0"/>

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


  <!-- Edit me links -->

  <xsl:template match="processing-instruction('edit_url')"/>
  <xsl:template match="ulink[@role='edit_me']">
    <xsl:variable name="custom_edit_url">
        <xsl:value-of select="normalize-space(preceding::processing-instruction('edit_url')[1])"/>
    </xsl:variable>

    <xsl:variable name="edit_url">
        <xsl:choose>
            <xsl:when test="$custom_edit_url != ''">
                <xsl:value-of select="$custom_edit_url" />
            </xsl:when>
            <xsl:when test="$local.edit_url">
                <xsl:value-of select="concat($local.edit_url,substring(attribute::url,string-length($local.root_dir)+1))" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="''" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:if test="$edit_url != ''">
        <a href="{$edit_url}" class="edit_me" title="Edit this page on GitHub" rel="nofollow">edit</a>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ulink[@role='edit_me']" mode="no.anchor.mode" />
 <!--  head title element with version -->

    <xsl:template name="user.header.content">
        <xsl:if test="$local.book.multi_version &gt; 0">
          <p>
             These docs are for branch: <xsl:value-of select="$local.book.version" />.
             <a href="../index.html">Other versions</a>.
          </p>
        </xsl:if>
    </xsl:template>

  <!-- remove part/chapter/section titles -->
  <xsl:param name="local.l10n.xml" select="document('')"/>
  <l:i18n xmlns:l="http://docbook.sourceforge.net/xmlns/l10n/1.0">
    <l:l10n language="en">
      <l:context name="title">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="title-unnumbered">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="title-numbered">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="xref">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="xref-number">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
      <l:context name="xref-number-and-title">
        <l:template name="part"    text="%t"/>
        <l:template name="chapter" text="%t"/>
        <l:template name="section" text="%t"/>
      </l:context>
    </l:l10n>
  </l:i18n>

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
  <xsl:template match="phrase[@revisionflag='added']">
    <span class="added">
      [<span class="version"><xsl:value-of select="attribute::revision" /></span>]
      <span class="detail">
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

  <xsl:template match="phrase[@revisionflag='changed']">
    <span class="coming">
      [<span class="version"><xsl:value-of select="attribute::revision" /></span>]
      <span class="detail">
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

  <xsl:template match="phrase[@revisionflag='deleted']">
    <span class="deprecated">
      [<span class="version"><xsl:value-of select="attribute::revision" /></span>]
      <span class="detail">
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

  <xsl:template match="phrase[@role='experimental']">
    <span class="experimental">
      [<span class="exp_title">experimental</span>]
      <span class="detail">
        <xsl:apply-templates />
      </span>
    </span>
  </xsl:template>

  <!-- Don't display in ToC -->
  <xsl:template match="phrase" mode="no.anchor.mode" />
  <xsl:template match="part[@role='exclude']
                      |appendix[@role='exclude']
                      |chapter[@role='exclude']
                      |section[@role='exclude']
                      |sect1[@role='exclude']"  mode="toc" />

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
          <xsl:if test="$admon.textlabel != 0 or title or info/title">
            <h4>
                <xsl:apply-templates select="." mode="object.title.markup"/>
            </h4>
          </xsl:if>
          <xsl:call-template name="anchor"/>
          <xsl:apply-templates/>
        </div>
      </div>
    </xsl:template>

    <!-- Sense widget -->
    <xsl:template match="remark[parent::answer|parent::appendix|parent::article|parent::bibliodiv|                                 parent::bibliography|parent::blockquote|parent::caution|parent::chapter|                                 parent::glossary|parent::glossdiv|parent::important|parent::index|                                 parent::indexdiv|parent::listitem|parent::note|parent::orderedlist|                                 parent::partintro|parent::preface|parent::procedure|parent::qandadiv|                                 parent::qandaset|parent::question|parent::refentry|parent::refnamediv|                                 parent::refsect1|parent::refsect2|parent::refsect3|parent::refsection|                                 parent::refsynopsisdiv|parent::sect1|parent::sect2|parent::sect3|parent::sect4|                                 parent::sect5|parent::section|parent::setindex|parent::sidebar|                                 parent::simplesect|parent::taskprerequisites|parent::taskrelated|                                 parent::tasksummary|parent::warning|parent::topic]">
      <xsl:if test="$show.comments != 0">
        <xsl:choose>
        <xsl:when test="contains(text(),'AUTOSENSE')">
            <div class="sense_widget" data-snippet=":AUTOSENSE:"></div>
        </xsl:when>
        <xsl:when test="contains(text(),'SENSE:')">
            <xsl:variable name="sense_url" select="translate(substring-after(text(),'SENSE:'),' ','')" />
            <div class="sense_widget" data-snippet="snippets/{$sense_url}"></div>
        </xsl:when>
        <xsl:when test="$local.comments != 0">
            <p class="remark"><xsl:call-template name="inline.charseq"/></p>
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
        <xsl:when test="contains(text(),'SENSE:')">
            <xsl:variable name="sense_url" select="translate(substring-after(text(),'SENSE:'),' ','')" />
            <div class="sense_widget" data-snippet="snippets/{$sense_url}"></div>
        </xsl:when>
        <xsl:when test="$local.comments != 0">
            <p class="remark"><xsl:call-template name="inline.charseq"/></p>
        </xsl:when>
        </xsl:choose>
      </xsl:if>
    </xsl:template>

</xsl:stylesheet>

