import {console_regex} from "./utils.js";
import $ from "jquery";

// Returns a thunk to preserve jQuery's `this` value but
// we need access to the lang_strings
// Used like:
// $('#guide').on('click', 'a.copy_as_curl', events.copy_as_curl(lang_strings));
export function copy_as_curl(lang_strings) {
  return function() {
    var regex = console_regex();
    var div = $(this);
    var consoleText = div.parent().prev().text() + '\n';
    var host = div.data('curl-host');
    var curlText = '';
    var match;

    while (match = regex.exec(consoleText)) {
      var comment = match[1];
      var method = match[2];
      var path = match[3];
      var body = match[4];
      if (comment) {
        curlText += comment + '\n';
      } else {
        path = path.replace(/^\//, '').replace(/\s+$/,'');
        if (method === "HEAD") {
          curlText += 'curl -I ';
        } else {
          curlText += 'curl -X ' + method + ' ';
        }
        curlText += '"' + host + '/' + path + '"';

        if (div.data('kibana')) {
          curlText += " -H 'kbn-xsrf: true'";
        } else {
          path += path.includes('?') ? '&pretty' : '?pretty';
        }

        if (body) {
          body = body.replace(/\'/g, '\\u0027');
          body = body.replace(/\s*$/,"\n");
          curlText += " -H 'Content-Type: application/json'";
          curlText += " -d'";
          var start = body.indexOf('"""');
          if (start < 0) {
            curlText += body;
          } else {
            var startOfNormal = 0;
            while (start >= 0) {
              var end = body.indexOf('"""', start + 3);
              if (end < 0) {
                end = body.length();
              }
              curlText += body.substring(startOfNormal, start);
              curlText += '"';
              var quoteBody = body.substring(start + 3, end);
              // Trim leading newline if there is one
              quoteBody = quoteBody.replace(/^\n+/, '');
              // Trim leading whitespace off of each line
              // But not more whitespace than is on the first line
              var leadingWhitespace = quoteBody.search(/\S/);
              if (leadingWhitespace > 0) {
                var leadingString = '^';
                for (var i = 0; i < leadingWhitespace; i++) {
                  leadingString += ' ';
                }
                quoteBody = quoteBody.replace(new RegExp(leadingString, 'gm'), '');
              }
              // Trim trailing whitespace
              quoteBody = quoteBody.replace(/\s+$/, '');
              // Escape for json
              quoteBody = quoteBody
                  .replace(/"/g, '\\"')
                  .replace(/\n/g, '\\n');
              curlText += quoteBody;
              curlText += '"';
              startOfNormal = end + 3;
              start = body.indexOf('"""', startOfNormal);
            }
            curlText += body.substring(startOfNormal);
          }
          curlText += "'";
        }
        curlText += '\n';
      }
    }
    var temp = $('<textarea>');
    $('body').append(temp);
    temp.val(curlText).select();
    var success = document.execCommand('copy');
    temp.remove();
    if (false == success) {
      console.error(lang_strings("Couldn't automatically copy!"));
      console.error(curlText);
    }
  };
}
