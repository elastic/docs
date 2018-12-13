/*!
 * JavaScript Cookie v2.1.1
 * https://github.com/js-cookie/js-cookie
 *
 * Copyright 2006, 2015 Klaus Hartl & Fagner Brack
 * Released under the MIT license
 */
;(function (factory) {
  if (typeof define === 'function' && define.amd) {
    define(factory);
  } else if (typeof exports === 'object') {
    module.exports = factory();
  } else {
    var OldCookies = window.Cookies;
    var api = window.Cookies = factory();
    api.noConflict = function () {
      window.Cookies = OldCookies;
      return api;
    };
  }
}(function () {
  function extend () {
    var i = 0;
    var result = {};
    for (; i < arguments.length; i++) {
      var attributes = arguments[ i ];
      for (var key in attributes) {
        result[key] = attributes[key];
      }
    }
    return result;
  }

  function init (converter) {
    function api (key, value, attributes) {
      var result;
      if (typeof document === 'undefined') {
        return;
      }

      // Write

      if (arguments.length > 1) {
        attributes = extend({
          path: '/'
        }, api.defaults, attributes);

        if (typeof attributes.expires === 'number') {
          var expires = new Date();
          expires.setMilliseconds(expires.getMilliseconds() + attributes.expires * 864e+5);
          attributes.expires = expires;
        }

        try {
          result = JSON.stringify(value);
          if (/^[\{\[]/.test(result)) {
            value = result;
          }
        } catch (e) {}

        if (!converter.write) {
          value = encodeURIComponent(String(value))
            .replace(/%(23|24|26|2B|3A|3C|3E|3D|2F|3F|40|5B|5D|5E|60|7B|7D|7C)/g, decodeURIComponent);
        } else {
          value = converter.write(value, key);
        }

        key = encodeURIComponent(String(key));
        key = key.replace(/%(23|24|26|2B|5E|60|7C)/g, decodeURIComponent);
        key = key.replace(/[\(\)]/g, escape);

        return (document.cookie = [
          key, '=', value,
          attributes.expires && '; expires=' + attributes.expires.toUTCString(), // use expires attribute, max-age is not supported by IE
          attributes.path    && '; path=' + attributes.path,
          attributes.domain  && '; domain=' + attributes.domain,
          attributes.secure ? '; secure' : ''
        ].join(''));
      }

      // Read

      if (!key) {
        result = {};
      }

      // To prevent the for loop in the first place assign an empty array
      // in case there are no cookies at all. Also prevents odd result when
      // calling "get()"
      var cookies = document.cookie ? document.cookie.split('; ') : [];
      var rdecode = /(%[0-9A-Z]{2})+/g;
      var i = 0;

      for (; i < cookies.length; i++) {
        var parts = cookies[i].split('=');
        var name = parts[0].replace(rdecode, decodeURIComponent);
        var cookie = parts.slice(1).join('=');

        if (cookie.charAt(0) === '"') {
          cookie = cookie.slice(1, -1);
        }

        try {
          cookie = converter.read ?
            converter.read(cookie, name) : converter(cookie, name) ||
            cookie.replace(rdecode, decodeURIComponent);

          if (this.json) {
            try {
              cookie = JSON.parse(cookie);
            } catch (e) {}
          }

          if (key === name) {
            result = cookie;
            break;
          }

          if (!key) {
            result[name] = cookie;
          }
        } catch (e) {}
      }

      return result;
    }

    api.set = api;
    api.get = function (key) {
      return api(key);
    };
    api.getJSON = function () {
      return api.apply({
        json: true
      }, [].slice.call(arguments));
    };
    api.defaults = {};

    api.remove = function (key, attributes) {
      api(key, '', extend(attributes, {
        expires: -1
      }));
    };

    api.withConverter = init;

    return api;
  }

  return init(function () {});
}));

// END jscookie

jQuery(function() {
  var lang = jQuery('section#guide[lang]').attr('lang') || 'en';
  var Strings;

  if (lang === 'en') {
    Strings = {
      "Configure Console URL" : "Configure Console URL",
      "Configure Sense URL" : "Configure Sense URL",
      "Copy as cURL" : "Copy as cURL",
      "Couldn't automatically copy!" : "Couldn't automatically copy!",
      "Default Console URL" : "Default Console URL",
      "Default Sense URL" : "Default Sense URL",
      "Default Kibana URL" : "Default Kibana URL",
      "Enter the URL of the Console editor" : "Enter the URL of the Console editor",
      "Enter the URL of the Sense editor" : "Enter the URL of the Sense editor",
      "Enter the URL of Kibana": "Enter the URL of Kibana",
      "On this page" : "On this page",
      "Open snippet in Console" : "Open snippet in Console",
      "Open snippet in Sense" : "Open snippet in Sense",
      "Or install Kibana" : 'Or install <a href="https://www.elastic.co/guide/en/kibana/master/setup.html">Kibana</a>.',
      "Or install Sense2" : 'Or install <a href="https://www.elastic.co/guide/en/sense/current/installing.html">the Sense 2 editor</a>.',
      "Save" : "Save",
      "This page is not available in the docs for version:" : "This page is not available in the docs for version:",
      "View in Sense" : "View in Sense",
      "View in Console" : "View in Console"
    };
  } else if (lang === 'zh_cn') {
    Strings = {
      "Configure Console URL" : "配置 Console URL",
      "Configure Sense URL" : "配置 Sense URL",
      "Copy as cURL" : "拷贝为 cURL",
      "Couldn't automatically copy!" : "无法自动拷贝!",
      "Default Console URL" : "默认 Console URL",
      "Default Sense URL" : "默认 Sense URL",
      "Default Kibana URL" : "默认 Kibana URL",
      "Enter the URL of the Console editor" : "输入 Console 编辑器的 URL",
      "Enter the URL of the Sense editor" : "输入 Sense 编辑器的 URL",
      "Enter the URL of Kibana": "输入 Kibana 的 URL",
      "On this page" : "本页导航",
      "Open snippet in Console" : "在 Console 中打开代码片段",
      "Open snippet in Sense" : "在 Sense 中打开代码片段",
      "Or install Kibana" : '或安装 <a href="https://www.elastic.co/guide/en/kibana/master/setup.html">Kibana</a>。',
      "Or install Sense2" : '或安装 <a href="https://www.elastic.co/guide/en/sense/current/installing.html">Sense 2 编辑器</a>。',
      "Save" : "保存",
      "This page is not available in the docs for version:" : "当前页在这些版本的文档中不可用：",
      "View in Sense" : "在 Sense 中查看",
      "View in Console" : "在 Console 中查看"
    };
  }

  // Move rtp container to top right and make visible
  var right_col = jQuery('#right_col');
  var this_page = jQuery('<div id="this_page"></div>').appendTo(right_col);

  jQuery('.page_header > a[href="../current/index.html"]').click(function() {
    get_current_page_in_version('current')
  });

  var default_kibana_url = 'http://localhost:5601';
  var default_console_url = default_kibana_url + '/app/kibana#/dev_tools/console';
  var default_sense_url = default_kibana_url + '/app/sense/';

  var kibana_url = Cookies.get('kibana_url') || default_kibana_url;
  var console_url = Cookies.get('console_url') || default_console_url;
  var sense_url = Cookies.get('sense_url') || default_sense_url;

  // Enable Sense widget
  init_sense_widgets(sense_url);
  init_console_widgets(console_url);
  init_kibana_widgets(kibana_url);

  function init_sense_widgets(sense_url) {
    var base_url = window.location.href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
      .replace(/^http:/, 'https:');
    jQuery('div.sense_widget').each(
      function() {
        var div = jQuery(this);
        var snippet = div.attr('data-snippet');
        div.html('<a class="sense_widget copy_as_curl" data-curl-host="localhost:9200">'
          + Strings['Copy as cURL']
          + '</a>'
          + '<a class="sense_widget" target="sense" '
          + 'title="'
          + Strings['Open snippet in Sense']
          + '" '
          + 'href="'
          + sense_url
          + '?load_from='
          + base_url
          + snippet
          + '">'
          + Strings['View in Sense']
          + '</a>'
          + '<a class="sense_settings" title="'
          + Strings['Configure Sense URL']
          + '">&nbsp;</a>');
        div.find('a.sense_settings').click(sense_settings);
      });
  }

  function init_console_widgets(console_url) {
    var base_url = window.location.href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
      .replace(/^http:/, 'https:');

    jQuery('div.console_widget').each(
      function() {
        var div = jQuery(this);
        var snippet = div.attr('data-snippet');
        div.html('<a class="sense_widget copy_as_curl" data-curl-host="localhost:9200">'
          + Strings['Copy as cURL']
          + '</a>'
          + '<a class="console_widget" target="console" '
          + 'title="'
          + Strings['Open snippet in Console']
          + '" '
          + 'href="'
          + console_url
          + '?load_from='
          + base_url
          + snippet
          + '">'
          + Strings['View in Console']
          + '</a>'
          + '<a class="console_settings" title="'
          + Strings['Configure Console URL']
          + '">&nbsp;</a>');
        div.find('a.console_settings').click(console_settings);
      });
    function console_regex() {
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

    jQuery('#guide').on('click', 'a.copy_as_curl', function() {
      var regex = console_regex();
      var div = jQuery(this);
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
          curlText += 'curl -X ' + method + ' "' + host + '/' + path + '"';

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
                  var leadingString = '^'
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
      var temp = jQuery('<textarea>');
      jQuery('body').append(temp);
      temp.val(curlText).select();
      var success = document.execCommand('copy');
      temp.remove();
      if (false == success) {
        console.error(Strings["Couldn't automatically copy!"]);
        console.error(curlText);
      }
    });
  }

  function init_kibana_widgets(kibana_url) {
    var base_url = window.location.href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
      .replace(/^http:/, 'https:');
    jQuery('div.kibana_widget').each(
      function() {
        var div = jQuery(this);
        var snippet = div.attr('data-snippet');
        div.html('<a class="kibana_widget copy_as_curl" data-curl-host="'
          + kibana_url
          + '" data-kibana="true">'
          + Strings['Copy as cURL']
          + '</a>'
          + '<a class="kibana_settings" title="'
          + Strings['Configure Kibana URL']
          + '">&nbsp</a>'
        );

        div.find('a.kibana_settings').click(kibana_settings);
      });
  }


  function sense_settings(e) {
    e.stopPropagation();
    if (jQuery('#sense_settings').length > 0) {
      return;
    }

    var div = jQuery('<div id="sense_settings">'
      + '<form>'
      + '<label for="sense_url">'
      + Strings['Enter the URL of the Sense editor']
      + '</label>'
      + '<input id="sense_url" type="text" value="'
      + sense_url
      + '" />'
      + '<button id="save_url" type="button">'
      + Strings['Save']
      + '</button>'
      + '<button id="reset_url" type="button">'
      + Strings['Default Sense URL']
      + '</button>'
      + '<p>'
      + Strings['Or install Sense2']
      + '</p>'
      + '</form></div>');

    jQuery('body').prepend(div);

    div.find('#save_url').click(function(e) {
      var new_url = jQuery('#sense_url').val() || default_sense_url;
      if (new_url === default_sense_url) {
        Cookies.set('sense_url', '');
      } else {
        Cookies.set('sense_url', new_url, {
          expires : 365
        });
      }
      sense_url = new_url;
      init_sense_widgets(sense_url);
      div.remove();
      e.stopPropagation();
    });
    div.find('#reset_url').click(function(e) {
      jQuery('#sense_url').val(default_sense_url);
      e.stopPropagation();
    });
  }

  function console_settings(e) {
    e.stopPropagation();
    if (jQuery('#console_settings').length > 0) {
      return;
    }

    var div = jQuery('<div id="console_settings">'
      + '<form>'
      + '<label for="console_url">'
      + Strings['Enter the URL of the Console editor']
      + '</label>'
      + '<input id="console_url" type="text" value="'
      + console_url
      + '" />'
      + '<button id="save_url"    type="button">'
      + Strings['Save']
      + '</button>'
      + '<button id="reset_url"   type="button">'
      + Strings['Default Console URL']
      + '</button>'
      + '<p>'
      + Strings['Or install Kibana']
      + '</p>'
      + '</form></div>');
    jQuery('body').prepend(div);

    div.find('#save_url').click(function(e) {
      var new_url = jQuery('#console_url').val() || default_console_url;
      if (new_url === default_console_url) {
        Cookies.set('console_url', '');
      } else {
        Cookies.set('console_url', new_url, {
          expires : 365
        });
      }
      console_url = new_url;
      init_console_widgets(console_url);
      div.remove();
      e.stopPropagation();
    });
    div.find('#reset_url').click(function(e) {
      jQuery('#console_url').val(default_console_url);
      e.stopPropagation();
    });
  }

  function kibana_settings(e) {
    e.stopPropagation();
    if (jQuery('#kibana_settings').length > 0) {
      return;
    }

    var div = jQuery('<div id="kibana_settings"><form><label for="kibana_url">'
      + Strings['Enter the URL of Kibana']
      + ':</label>'
      + '<input id="kibana_url" type="text" value="'
      + kibana_url
      + '" />'
      + '<button id="save_url" type="button">'
      + Strings['Save']
      + '</button>'
      + '<button id="reset_url" type="button">'
      + Strings['Default Kibana URL']
      + '</button>'
      + '<p>'
      + Strings['Or install Kibana']
      + '</p></form></div>'
    );

    jQuery('body').prepend(div);

    div.find('#save_url').click(function(e) {
      var new_url = jQuery('#kibana_url').val() || default_kibana_url;
      if (new_url === default_kibana_url) {
        Cookies.set('kibana_url', '');
      } else {
        Cookies.set('kibana_url', new_url, {
          expires : 365
        });
      }
      kibana_url = new_url;
      init_kibana_widgets(kibana_url);
      div.remove();
      e.stopPropagation();
    });
    div.find('#reset_url').click(function(e) {
      jQuery('#kibana_url').val(default_kibana_url);
      e.stopPropagation();
    });
  }

  function get_current_page_in_version(version) {
    var url = location.href;
    var url = location.href.replace(/[^\/]+\/+([^\/]+\.html)/, version + "/$1");
    return jQuery.get(url).done(function() {
      location.href = url
    });
  }

  function init_toc() {

    var title = jQuery('#book_title');

    // Make li elements in toc collapsible
    jQuery('div.toc li ul').each(function() {
      var li = jQuery(this).parent();
      li.addClass('collapsible').children('span').click(function() {
        if (li.hasClass('show')) {
          li.add(li.find('li.show')).removeClass('show');
          if (title.hasClass('show')) {
            title.removeClass('show');
          }
        } else {
          li.parents('div.toc,li').first().find('li.show').removeClass('show');
          li.addClass('show');
        }
      });
    });

    // Make book title in toc collapsible
    if (jQuery('.collapsible').length > 0) {
      title.addClass('collapsible').click(function() {
        if (title.hasClass('show')) {
          title.removeClass('show');
          title.parent().find('.show').removeClass('show');
        } else {
          title.addClass('show');
          title.parent().find('.collapsible').addClass('show');
        }
      });
    }

    // Clicking links or the version selector shouldn't fold/expand
    jQuery('div.toc a, #book_title select').click(function(e) {
      e.stopPropagation()
    });

    // Setup version selector
    var v_selected = title.find('select option:selected');
    title
      .find('select')
      .change(
        function() {
          var version = title.find('option:selected').val();
          get_current_page_in_version(version)
            .fail(
              function() {
                v_selected.attr('selected', 'selected');
                alert(Strings['This page is not available in the docs for version:']
                  + version)
              })
        });
  }

  function init_headers() {
    // Add on-this-page block
    this_page.append('<h2>' + Strings['On this page'] + '</h2>');
    var ul = jQuery('<ul></ul>').appendTo(this_page);
    var items = 0;

    jQuery('#guide a[id]').each(
      function() {
        // Make headers into real links for permalinks
        this.href = '#' + this.id;

        // Extract on-this-page headers, without embedded links
        var title_container = jQuery(this).parent('h1,h2,h3').clone();
        if (title_container.length > 0) {
          // Exclude page title
          if (0 < items++) {
            title_container.find('a,.added,.coming,.deprecated,.experimental')
              .remove();
            var text = title_container.html();
            ul.append('<li><a href="#' + this.id + '">' + text + '</a></li>');
          }
        }
      });
    if (items < 2) {
      this_page.remove();
    }
  }

  // Expand ToC to current page (without #)
  function open_current() {
    var page = location.pathname.match(/[^\/]+$/)[0];
    var current = jQuery('div.toc a[href="' + page + '"]');
    current.addClass('current_page');
    current.parentsUntil('ul.toc', 'li.collapsible').addClass('show');
  }

  var div = jQuery('div.toc');
  // Fetch toc.html unless there is already a .toc on the page
  if (div.length == 0
    && jQuery('#guide').find('div.article,div.book').length == 0) {
    var url = location.href.replace(/[^\/]+$/, 'toc.html');
    var toc = jQuery.get(url, {}, function(data) {
      right_col.append(data);
      init_toc();
      open_current();
    }).always(init_headers);
  } else {
    init_toc();
  }
});
