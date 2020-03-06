import {$} from "./deps";

export function get_base_url(href) {
  return href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
             .replace(/^http:/, 'https:');
}

const VERSION_REGEX = /[^\/]+\/+([^\/]+\.html)/;
export function get_current_page_in_version(version) {
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

/*
  Parse query strings in a battle-tested, good practice manner.
  An extraction of the deparam method from Ben Alman's jQuery BBQ plugin
  http://benalman.com/projects/jquery-bbq-plugin/
  Exact source: https://github.com/cowboy/jquery-bbq/blob/8e0064ba68a34bcd805e15499cb45de3f4cc398d/jquery.ba-bbq.js#L466
  Unit tests maintained separately: http://benalman.com/code/projects/jquery-bbq/unit/
  Licence: dual-licensed under MIT and GPL, we use https://github.com/cowboy/jquery-bbq/blob/8e0064ba68a34bcd805e15499cb45de3f4cc398d/LICENSE-MIT
*/
export function deparam(params, coerce) {
  var obj = {},
      coerce_types = { 'true': !0, 'false': !1, 'null': null };

  // Iterate over all name=value pairs.
  $.each(params.replace(/\+/g, ' ').split('&'), function (j,v) {
    var param = v.split('='),
        key = decodeURIComponent(param[0]),
        val,
        cur = obj,
        i = 0,

        // If key is more complex than 'foo', like 'a[]' or 'a[b][c]', split it
        // into its component parts.
        keys = key.split(']['),
        keys_last = keys.length - 1;

    // If the first keys part contains [ and the last ends with ], then []
    // are correctly balanced.
    if (/\[/.test(keys[0]) && /\]$/.test(keys[keys_last])) {
      // Remove the trailing ] from the last keys part.
      keys[keys_last] = keys[keys_last].replace(/\]$/, '');

      // Split first keys part into two parts on the [ and add them back onto
      // the beginning of the keys array.
      keys = keys.shift().split('[').concat(keys);

      keys_last = keys.length - 1;
    } else {
      // Basic 'foo' style key.
      keys_last = 0;
    }

    // Are we dealing with a name=value pair, or just a name?
    if (param.length === 2) {
      val = decodeURIComponent(param[1]);

      // Coerce values.
      if (coerce) {
        val = val && !isNaN(val)              ? +val              // number
            : val === 'undefined'             ? undefined         // undefined
            : coerce_types[val] !== undefined ? coerce_types[val] // true, false, null
            : val;                                                // string
      }

      if ( keys_last ) {
        // Complex key, build deep object structure based on a few rules:
        // * The 'cur' pointer starts at the object top-level.
        // * [] = array push (n is set to array length), [n] = array if n is
        //   numeric, otherwise object.
        // * If at the last keys part, set the value.
        // * For each keys part, if the current level is undefined create an
        //   object or array based on the type of the next keys part.
        // * Move the 'cur' pointer to the next level.
        // * Rinse & repeat.
        for (; i <= keys_last; i++) {
          key = keys[i] === '' ? cur.length : keys[i];
          cur = cur[key] = i < keys_last
            ? cur[key] || (keys[i+1] && isNaN(keys[i+1]) ? {} : [])
            : val;
        }

      } else {
        // Simple key, even simpler rules, since only scalars and shallow
        // arrays are allowed.

        if ($.isArray(obj[key])) {
          // val is already an array, so push on the next value.
          obj[key].push( val );

        } else if (obj[key] !== undefined) {
          // val isn't an array, but since a second value has been specified,
          // convert val into an array.
          obj[key] = [obj[key], val];

        } else {
          // val is a scalar.
          obj[key] = val;
        }
      }

    } else if (key) {
      // No value was defined, so set something meaningful.
      obj[key] = coerce
        ? undefined
        : '';
    }
  });

  return obj;
};
