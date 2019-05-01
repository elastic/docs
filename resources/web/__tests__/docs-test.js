'use strict';

const dedent = require('dedent');

window.jQuery = require('jquery');

document.body.innerHTML = dedent `
  <div id="guide">
    <div class="pre_wrapper">
      <pre class="programlisting prettyprint lang-js">
        GET /_cat/health?v
      </pre>
    </div>
    <div class="console_widget" data-snippet="snippets/getting-started-cluster-health/1.json"></div>
  </div>
`;

window.Cookies = jest.fn();
window.Cookies.get = jest.fn();
require('../docs.js');
jQuery.ready();

describe('console widget', () => {
  describe('Copy as cURL button', () => {
    const copyAsCurl = jQuery('.copy_as_curl');
    it('to exist', () => {
      expect(copyAsCurl).toHaveLength(1);
    });
    describe('when clicked', () => {
      document.execCommand = jest.fn(() => {
        document.copied = jQuery('textarea').val();
        return true;
      });
      copyAsCurl.click();
      it('copies the text to the clipboard', () => {
        expect(document.execCommand).toHaveBeenCalledWith('copy');
        expect(document.copied).toEqual(dedent `
          curl -X GET "localhost:9200/_cat/health?v" -H 'Content-Type: application/json' -d'
          '
        ` + '\n');
      }) 
    });
  });
});