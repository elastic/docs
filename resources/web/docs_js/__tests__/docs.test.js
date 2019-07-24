import {jQuery, dedent} from "../deps" ;
import * as docs from "../index";
import * as l from "../localization";

const LangStrings = l.lang_strings('en');

function pageWithConsole(name, consoleText, extraTextAssertions) {
  describe(name, () => {
    let copyAsCurl;
    beforeEach(() => {
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

      docs.init_console_widgets('localhost:5601/app/kibana#/dev_tools/console', LangStrings);
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
        copyAsCurl.click();
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
  describe('Copy as cURL button', () => {
    pageWithConsole('a snippet without a body', 'GET /_cat/health?v', () => {
      test('includes the corrent method', () => {
        expect(document.copied).toMatch(/-X GET/);
      });
      test('includes the url', () => {
        expect(document.copied).toMatch(/"localhost:9200\/_cat\/health\?v"/);
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
        expect(document.copied).toMatch(/"localhost:9200\/twitter\/_doc\/1"/);
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
        <div id="guide">
          ${guideBody}
        </div>
        <div id="right_col">
          <div id="other_stuff" />
        </div>
      `;

      const rightCol = jQuery('#right_col');
      docs.init_headers(rightCol, LangStrings);
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
    <h3>
      <a id="nrt"></a>
      Near Realtime (NRT)
    </h3>
  `;
  const twoSubsections = dedent `
    ${oneSubsection}
    <h3>
      <a id="cluster"></a>
      Cluster
    </h3>
  `;

  describeInitHeaders('for page with just a title', onlyTitle, () => {
    test("doesn't exist", () => {
      expect(jQuery('#this_page')).toHaveLength(0);
    });
  });

  function existsAssertions() {
    test('exists', () => {
      expect(jQuery('#this_page')).toHaveLength(1);
    });
    test('be before any other right column content', () => {
      expect(jQuery('#right_col').children().get(0).id).toEqual('this_page');
      expect(jQuery('#right_col').children().get(1).id).toEqual('other_stuff');
      expect(jQuery('#right_col').children()).toHaveLength(2);
    });
  }
  describeInitHeaders('for page with one subsection', oneSubsection, () => {
    existsAssertions();
    test('contains a link to the subsection header', () => {
      const link = jQuery('#this_page a[href="#nrt"]');
      expect(link).toHaveLength(1);
      expect(link.text().trim()).toEqual('Near Realtime (NRT)');
    });
  });
  describeInitHeaders('for page with two subsections', twoSubsections, () => {
    existsAssertions();
    test('contains a link to the first subsection header', () => {
      const link = jQuery('#this_page a[href="#nrt"]');
      expect(link).toHaveLength(1);
      expect(link.text().trim()).toEqual('Near Realtime (NRT)');
    });
    test('contains a link to the second subsection header', () => {
      const link = jQuery('#this_page a[href="#cluster"]');
      expect(link).toHaveLength(1);
      expect(link.text().trim()).toEqual('Cluster');
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

    docs.open_current("/guide/blocks.html");
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
