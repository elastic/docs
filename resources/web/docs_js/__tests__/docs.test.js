import {jQuery} from "../deps";
import dedent from "../../../../../node_modules/dedent";
import {init_console_widgets, init_headers} from "../index-v2";
import * as utils from "../utils";
import * as l from "../localization";
import store from "../store";

const LangStrings = l.lang_strings('en');

function pageWithConsole(name, consoleText, extraTextAssertions) {
  describe(name, () => {
    let copyAsCurl;
    beforeEach(() => {
      store({
        settings: {
          language: "en",
          langStrings: LangStrings,
          console_url: "localhost:5601/app/kibana#/dev_tools/console",
          baseUrl: "https://localhost:8000/guide/",
          console_curl_host: "localhost:9200"
        }
      });

      document.body.innerHTML = dedent `
        <div id="guide">
          <div class="pre_wrapper">
            <pre class="programlisting prettyprint lang-js">
              ${consoleText}
            </pre>
          </div>
          <div class="console_widget" data-snippet="snippets/getting-started-cluster-health/1.json"></div>
        </div>
      `;

      init_console_widgets();
      copyAsCurl = jQuery('.copy_as_curl');
    });

    test('exists', () => {
      expect(copyAsCurl).toHaveLength(1);
    });
    describe('when clicked', () => {
      beforeEach(() => {
        document.execCommand = jest.fn(() => {
          document.copied = jQuery('textarea').val();
          return true;
        });
        copyAsCurl[0].click();
      });
      test('copies a curl command to the clipboard', () => {
        expect(document.execCommand).toHaveBeenCalledWith('copy');
      });
      describe('the copied text', () => {
        test('starts with curl', () => {
          expect(document.copied).toMatch(/^curl/);
        });
        test('includes a method', () => {
          expect(document.copied).toMatch(/-X/);
        });
        test('includes the Content-Type', () => {
          expect(document.copied).toMatch(/-H 'Content-Type: application\/json'/);
        });
        test('has a trailing newline', () => {
          expect(document.copied).toMatch(/\n$/);
        });
        extraTextAssertions();
      });
    });
  });
}

describe('console widget', () => {
  describe('Copy as curl button', () => {
    pageWithConsole('a snippet without a body', 'GET /_cat/health?v', () => {
      test('includes the corrent method', () => {
        expect(document.copied).toMatch(/-X GET/);
      });
      test('includes the url', () => {
        expect(document.copied).toMatch(/"localhost:9200\/_cat\/health\?v&pretty"/);
      });
    });

    const withBody = dedent `
      PUT twitter/_doc/1
      {
          "user" : "kimchy",
          "post_date" : "2009-11-15T14:12:12",
          "message" : "trying out Elasticsearch"
      }
    `

    pageWithConsole('a snippet with a body', withBody, () => {
      test('includes the method', () => {
        expect(document.copied).toMatch(/-X PUT/);
      });
      test('includes the url', () => {
        expect(document.copied).toMatch(/"localhost:9200\/twitter\/_doc\/1\?pretty"/);
      });
      test('includes the body', () => {
        expect(document.copied).toEqual(expect.stringContaining(dedent `
          -d'
          {
          "user" : "kimchy",
          "post_date" : "2009-11-15T14:12:12",
          "message" : "trying out Elasticsearch"
          }
          '
        `));
      });
    });
  });
});

function describeInitHeaders(name, guideBody, onThisPageAssertions) {
  describe(name, () => {
    beforeEach(() => {
      document.body.innerHTML = dedent `
      <div id="content">
        ${guideBody}
      </div>
      <div id="right-sidebar">
        <div id="right-sidebar-container">
          <div id="version-selectors-full"></div>
        </div>
      </div>
      `;

      const rightSidebar = jQuery('#right-sidebar-container');
      init_headers(rightSidebar, LangStrings);
    });

    describe('the "On This Page" section', () => {
      onThisPageAssertions();
    });
  });
}

describe('On This Page', () => {
  const onlyTitle = dedent `
    <h2>
      <a id="getting-started"></a>
      Getting Started
    </h2>
  `;
  const oneSubsection = dedent `
    ${onlyTitle}
    <h2>
      <a id="nrt"></a>
      Near Realtime (NRT)
    </h2>
  `;
  const twoSubsections = dedent `
    ${oneSubsection}
    <h2>
      <a id="cluster"></a>
      Cluster
    </h2>
  `;
  const fourSubsections = dedent `
    ${twoSubsections}
    <h3>
      <a id="observability"></a>
      Observability
    </h3>
    <h4>
      <a id="apm"></a>
      APM
    </h4>
  `;

  function existsAssertions() {
    test('exists', () => {
      expect(jQuery('#on-this-page-container')).toHaveLength(1);
    });
  }
  describeInitHeaders('for page with one subsection', oneSubsection, () => {
    test('contains a link to the subsection header', () => {
      const link = jQuery('#on-this-page-container a[href="#nrt"]');
      expect(link).toBeTruthy();
      expect(link.text().trim()).toEqual('Near Realtime (NRT)');
    });
  });
  describeInitHeaders('for page with two subsections', twoSubsections, () => {
    test('contains a link to the first subsection header', () => {
      const link = jQuery('#on-this-page-container a[href="#nrt"]');
      expect(link).toBeTruthy();
      expect(link.text().trim()).toEqual('Near Realtime (NRT)');
    });
    test('contains a link to the second subsection header', () => {
      const link = jQuery('#on-this-page-container a[href="#cluster"]');
      expect(link).toBeTruthy();
      expect(link.text().trim()).toEqual('Cluster');
    });
    test('similar heading sections should be nested correctly', () => {
      const link1 = jQuery('#on-this-page-container a[href="#nrt"]');
      const link2 = jQuery('#on-this-page-container a[href="#cluster"]');
      expect(link1.parent().hasClass('heading-level-0')).toBe(true);
      expect(link2.parent().hasClass('heading-level-0')).toBe(true);
    });
  });
  describeInitHeaders('for page with four subsections', fourSubsections, () => {
    existsAssertions();
    test('different heading sections should be nested correctly', () => {
      const link1 = jQuery('#on-this-page-container a[href="#nrt"]');
      const link2 = jQuery('#on-this-page-container a[href="#cluster"]');
      const link3 = jQuery('#on-this-page-container a[href="#observability"]');
      const link4 = jQuery('#on-this-page-container a[href="#apm"]');
      expect(link1.parent().hasClass('heading-level-0')).toBe(true);
      expect(link2.parent().hasClass('heading-level-0')).toBe(true);
      expect(link3.parent().hasClass('heading-level-1')).toBe(true);
      expect(link4.parent().hasClass('heading-level-2')).toBe(true);
    });
  });
});

describe("Open current TOC", () => {
  beforeEach(() => {
    document.body.innerHTML = dedent `
      <div class="toc">
        <a href="lists.html">Lists</a>
        <ul class="toc">
          <li class="collapsible">
            <a href="blocks.html">Blocks</a>
          </li>
        </ul>
      </div>
    `;

    utils.open_current("/guide/blocks.html");
  });

  test("It adds the current_page class to the correct element", () => {
    const el = jQuery('div.toc a[href="blocks.html"]');
    expect(el.hasClass("current_page")).toBe(true);
  });

  test("It adds the show class to the correct parent element", () => {
    const li = jQuery("li.collapsible");
    expect(li.hasClass("show")).toBe(true);
  });
});
