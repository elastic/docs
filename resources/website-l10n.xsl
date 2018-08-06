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
        <l:template name="bridgehead" text="%t"/>
        <l:template name="refsection" text="%t"/>
        <l:template name="refsect1" text="%t"/>
        <l:template name="refsect2" text="%t"/>
        <l:template name="refsect3" text="%t"/>
        <l:template name="sect1" text="%t"/>
        <l:template name="sect2" text="%t"/>
        <l:template name="sect3" text="%t"/>
        <l:template name="sect4" text="%t"/>
        <l:template name="sect5" text="%t"/>
        <l:template name="section" text="%t"/>
        <l:template name="simplesect" text="%t"/>
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
        <l:template name="beta-text" text="This functionality is in beta and is subject to change. The design and code is less mature than official GA features and is being provided as-is with no warranties. Beta features are not subject to the support SLA of official GA features." />
        <l:template name="coming" text="Coming in " />
        <l:template name="deprecated" text="Deprecated in " />
        <l:template name="experimental" text="experimental" />
        <l:template name="experimental-text" text="This functionality is experimental and may be changed or removed completely in a future release. Elastic will take a best effort approach to fix any issues, but experimental features are not subject to the support SLA of official GA features." />
        <l:template name="sentence-separator" text=". " />
      </l:context>
    </l:l10n>

    <l:l10n language="zh_cn">
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
        <l:template name="bridgehead" text="%t"/>
        <l:template name="refsection" text="%t"/>
        <l:template name="refsect1" text="%t"/>
        <l:template name="refsect2" text="%t"/>
        <l:template name="refsect3" text="%t"/>
        <l:template name="sect1" text="%t"/>
        <l:template name="sect2" text="%t"/>
        <l:template name="sect3" text="%t"/>
        <l:template name="sect4" text="%t"/>
        <l:template name="sect5" text="%t"/>
        <l:template name="section" text="%t"/>
        <l:template name="simplesect" text="%t"/>
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
        <l:template name="edit-me-title" text="在 GitHub 上编辑本页" />
        <l:template name="edit-me-text" text="编辑" />
      </l:context>
      <l:context name="meta">
        <l:template name="meta-description" text="有关如何使用 Elasticsearch、Kibana、Logstash、Beats、X-Pack、Elastic Cloud、Elasticsearch for Apache Hadoop 及我们各种语言的客户端的文档。" />
      </l:context>
      <l:context name="annotation">
        <l:template name="added" text="添加于" />
        <l:template name="beta" text="beta" />
        <l:template name="beta-text" text="这个功能当前处于测试阶段，随时可能发生变化。与正式的 GA 特性相比被认为是不成熟的设计和代码。Elastic 会尽最大努力来解决任何问题，但是 beta 特性不在官方提供的 SLA 支持列表（ 仅支持 GA 特性）。" />
        <l:template name="coming" text="将来自" />
        <l:template name="deprecated" text="废弃于" />
        <l:template name="experimental" text="实验" />
        <l:template name="experimental-text" text="这个功能是实验性的，可能在将来的版本完全被改变或删除。Elastic 会尽最大努力来解决任何问题，但是实验特性不在官方提供的 SLA 支持列表（ 仅支持 GA 特性）。" />
        <l:template name="sentence-separator" text="。" />
      </l:context>
    </l:l10n>

    <l:l10n language="ja">
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
        <l:template name="bridgehead" text="%t"/>
        <l:template name="refsection" text="%t"/>
        <l:template name="refsect1" text="%t"/>
        <l:template name="refsect2" text="%t"/>
        <l:template name="refsect3" text="%t"/>
        <l:template name="sect1" text="%t"/>
        <l:template name="sect2" text="%t"/>
        <l:template name="sect3" text="%t"/>
        <l:template name="sect4" text="%t"/>
        <l:template name="sect5" text="%t"/>
        <l:template name="section" text="%t"/>
        <l:template name="simplesect" text="%t"/>
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
        <l:template name="edit-me-title" text="GitHub上で編集" />
        <l:template name="edit-me-text" text="編集" />
      </l:context>
      <l:context name="meta">
        <l:template name="meta-description" text="Elasticsearch、Kibana、Logstash、Beats、X-Pack、Elastic Cloud、Elasticsearch for Apache Hadoop そして、さまざまな言語のクライアントの使用方法に関するドキュメント。" />
      </l:context>
      <l:context name="annotation">
        <l:template name="added" text="追加されたバージョン：" />
        <l:template name="beta" text="ベータ版：" />
        <l:template name="beta-text" text="この機能は現在テスト段階にあり、変更される可能性があります。 正式なGAの機能と比較して未熟な設計とコードとみなされます。 Elasticは問題を解決するために最善を尽くしますが、ベータ版の機能は公式のSLAサポートリスト（GAのみ）の対象ではありません。" />
        <l:template name="coming" text="導入予定：" />
        <l:template name="deprecated" text="廃止予定：" />
        <l:template name="experimental" text="実験的" />
        <l:template name="experimental-text" text="この機能は実験的なものであり、将来のバージョンでは完全に変更または削除される可能性があります。 Elasticは問題を解決するために最善を尽くしますが、実験的な機能は公式SLAサポートリスト（GAのみ）では利用できません。" />
        <l:template name="sentence-separator" text="。" />
      </l:context>
    </l:l10n>

    <l:l10n language="ko">
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
        <l:template name="bridgehead" text="%t"/>
        <l:template name="refsection" text="%t"/>
        <l:template name="refsect1" text="%t"/>
        <l:template name="refsect2" text="%t"/>
        <l:template name="refsect3" text="%t"/>
        <l:template name="sect1" text="%t"/>
        <l:template name="sect2" text="%t"/>
        <l:template name="sect3" text="%t"/>
        <l:template name="sect4" text="%t"/>
        <l:template name="sect5" text="%t"/>
        <l:template name="section" text="%t"/>
        <l:template name="simplesect" text="%t"/>
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
        <l:template name="edit-me-title" text="GitHub에서 편집" />
        <l:template name="edit-me-text" text="편집" />
      </l:context>
      <l:context name="meta">
        <l:template name="meta-description" text="Elasticsearch、Kibana、Logstash、Beats、X-Pack、Elastic Cloud、Elasticsearch for Apache Hadoop, 그 밖에 다양한 언어용 클라이언트 소개" />
      </l:context>
      <l:context name="annotation">
        <l:template name="added" text="추가" />
        <l:template name="beta" text="beta" />
        <l:template name="beta-text" text="이 기능은 현재 테스트 단계에 있으며 언제든지 변경될 수 있습니다. 정식 GA 기능에 비해 미숙한 설계와 코드로 간주됩니다. Elastic은 문제를 해결하기 위해 최선을 다하고 있지만 베타 기능은 공식적인 기능(GA)과 달리 지원 SLA에 따르지 않습니다." />
        <l:template name="coming" text="오는" />
        <l:template name="deprecated" text="Deprecated" />
        <l:template name="experimental" text="실험적" />
        <l:template name="experimental-text" text="이 기능은 실험적인 것이며, 향후 버전에서는 완전히 변경되거나 삭제될 수 있습니다. Elastic은 문제를 해결하기 위해 최선을 다하고 있지만, 실험적인 기능은 공식적인 기능(GA)과 달리 지원 SLA에 따르지 않습니다." />
        <l:template name="sentence-separator" text=". " />
      </l:context>
    </l:l10n>
  </l:i18n>
</xsl:stylesheet>
