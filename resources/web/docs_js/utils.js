import {$} from "./deps";

export function get_base_url(href) {
  return href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
             .replace(/^http:/, 'https:');
}

const VERSION_REGEX = /[^\/]+\/+([^\/]+\.html)/;
export function get_current_page_in_version(version) {
  if (version === "other") {
    location.href = location.href.replace(VERSION_REGEX, "index.html");
  }
  var url = location.href.replace(VERSION_REGEX, version + "/$1");
  return $.get(url).done(function() {
    location.href = url
  });
}

// Expand ToC to current page (without #)
export function open_current(pathname) {
  var page = pathname.match(/[^\/]+$/)[0];
  var current = $('div.toc a[href="' + page + '"]');
  current.addClass('current_page');
  current.parentsUntil('ul.toc', 'li.collapsible').addClass('show');
}

export function console_regex() {
  // Port of
  // https://github.com/elastic/elasticsearch/blob/master/buildSrc/src/main/groovy/org/elasticsearch/gradle/doc/RestTestsFromSnippetsTask.groovy#L71-L79
  var method = '(GET|PUT|POST|HEAD|OPTIONS|DELETE)';
  var pathAndQuery = '([^\\n]+)';
  var badBody = 'GET|PUT|POST|HEAD|OPTIONS|DELETE|#';
  var body = '((?:\\n(?!$badBody)[^\\n]+)+)'.replace('$badBody', badBody);
  var nonComment = '$method\\s+$pathAndQuery$body?'.replace(
    '$method',
    method).replace('$pathAndQuery', pathAndQuery).replace('$body', body);
  var comment = '(#.+)';
  return new RegExp('(?:$comment|$nonComment)\\n+'.replace(
    '$comment',
    comment).replace('$nonComment', nonComment), 'g');
}

export function copyText(text, langStrings) {
  var temp = $('<textarea>');
  $('body').append(temp);
  temp.val(text).select();
  var success = document.execCommand('copy');
  temp.remove();
  if (false == success) {
    console.error(langStrings("Couldn't automatically copy!"));
    console.error(text);
  }
}

export const getCurlText = ({consoleText,
                             curl_host,
                             curl_user,
                             curl_password,
                             isKibana,
                             addPretty}) => {
  var regex    = console_regex(),
      curlText = '',
      match;

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

      if (curl_user && curl_password) {
        curlText += `-u ${curl_user}:${curl_password} `;
      }

      if (addPretty) {
        path += path.includes('?') ? '&pretty' : '?pretty';
      }

      curlText += '"' + curl_host + '/' + path + '"';

      if (isKibana) {
        curlText += " -H 'kbn-xsrf: true'";
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

  return curlText;
}
