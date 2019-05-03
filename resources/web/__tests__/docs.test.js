const dedent = require('dedent');
window.jQuery = require('jquery');
const docs = require('../docs.js');
docs.init_strings('en');

function pageWithConsole(name, consoleText, extraTextMatchers) {
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

      docs.init_console_widgets('localhost:5601/app/kibana#/dev_tools/console');
      copyAsCurl = jQuery('.copy_as_curl');
    });

    it('to exist', () => {
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
      it('copies a curl command to the clipboard', () => {
        expect(document.execCommand).toHaveBeenCalledWith('copy');
      });
      describe('the copied text', () => {
        it('starts with curl', () => {
          expect(document.copied).toMatch(/^curl/)
        });
        it('includes a method', () => {
          expect(document.copied).toMatch(/-X/)
        });
        it('includes the Content-Type', () => {
          expect(document.copied).toMatch(/-H 'Content-Type: application\/json'/);
        });
        it('has a trailing newline', () => {
          expect(document.copied).toMatch(/\n$/);
        });
        extraTextMatchers();
      });
    });
  });
}

describe('console widget', () => {
  describe('Copy as cURL button', () => {
    pageWithConsole('a snippet without a body', 'GET /_cat/health?v', () => {
      it('includes the corrent method', () => {
        expect(document.copied).toMatch(/-X GET/)
      });
      it('includes the url', () => {
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
      it('includes the method', () => {
        expect(document.copied).toMatch(/-X PUT/)
      });
      it('includes the url', () => {
        expect(document.copied).toMatch(/"localhost:9200\/twitter\/_doc\/1"/);
      });
      it('include the body', () => {
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
      it('has a trailing newline', () => {
        expect(document.copied).toMatch(/\n$/);
      });
    });
  });
});