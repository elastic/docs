<xsl:stylesheet version="1.0"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

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
      <l:context name="edit-me">
        <l:template name="edit-me-title" text="Edit this page on GitHub" />
        <l:template name="edit-me-text" text="edit" />
      </l:context>
      <l:context name="meta">
        <l:template name="meta-description" text="Get started with the documentation for Elasticsearch, Kibana, Logstash, Beats, X-Pack, Elastic Cloud, Elasticsearch for Apache Hadoop, and our language clients." />
      </l:context>
      <l:context name="annotation">
        <l:template name="added" text="Added in " />
        <l:template name="beta" text="beta" />
        <l:template name="beta-text" text="This functionality is in beta and is subject to change. The design and code is considered to be less mature than official GA features. Elastic will take a best effort approach to fix any issues, but beta features are not subject to the support SLA of official GA features." />
        <l:template name="coming" text="Coming in " />
        <l:template name="deprecated" text="Deprecated in " />
        <l:template name="experimental" text="experimental" />
        <l:template name="experimental-text" text="This functionality is experimental and may be changed or removed completely in a future release. Elastic will take a best effort approach to fix any issues, but experimental features are not subject to the support SLA of official GA features." />
        <l:template name="sentence-separator" text=". " />
      </l:context>
    </l:l10n>

    <l:l10n language="zh">
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
      <l:context name="edit-me">
        <l:template name="edit-me-title" text="Edit this page on GitHub" />
        <l:template name="edit-me-text" text="edit" />
      </l:context>
      <l:context name="meta">
        <l:template name="meta-description" text="Get started with the documentation for Elasticsearch, Kibana, Logstash, Beats, X-Pack, Elastic Cloud, Elasticsearch for Apache Hadoop, and our language clients." />
      </l:context>
      <l:context name="annotation">
        <l:template name="added" text="Added in " />
        <l:template name="beta" text="beta" />
        <l:template name="beta-text" text="This functionality is in beta and is subject to change. The design and code is considered to be less mature than official GA features. Elastic will take a best effort approach to fix any issues, but beta features are not subject to the support SLA of official GA features." />
        <l:template name="coming" text="Coming in " />
        <l:template name="deprecated" text="Deprecated in " />
        <l:template name="experimental" text="experimental" />
        <l:template name="experimental-text" text="This functionality is experimental and may be changed or removed completely in a future release. Elastic will take a best effort approach to fix any issues, but experimental features are not subject to the support SLA of official GA features." />
        <l:template name="sentence-separator" text=". " />
      </l:context>
    </l:l10n>

  </l:i18n>
</xsl:stylesheet>
