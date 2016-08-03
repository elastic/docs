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
  // Move rtp container to top right and make visible
  var right_col = jQuery('#right_col');
  var this_page = jQuery('<div id="this_page"></div>').appendTo(right_col);

  var default_console_url = 'http://localhost:5601/app/console/';
  var default_sense_url = 'http://localhost:5601/app/sense/';
  var default_sense_url_marvel = 'http://localhost:9200/_plugin/marvel/sense/';
  var console_url = Cookies.get('console_url') || default_console_url;
  var sense_url = Cookies.get('sense_url') || default_sense_url;

  // Enable Sense widget
  init_sense_widgets(sense_url);
  init_console_widgets(console_url);

  function init_sense_widgets(sense_url) {
    var base_url = window.location.href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
      .replace(/^http:/, 'https:');
    jQuery('div.sense_widget')
      .each(
        function() {
          var div = jQuery(this);
          var snippet = div.attr('data-snippet');
          div
            .html('<a class="sense_widget" target="sense" '
              + 'title="Open snippet in Sense" '
              + 'href="'
              + sense_url
              + '?load_from='
              + base_url
              + snippet
              + '">View in Sense</a>'
              + '<a class="sense_settings" title="Configure Sense URL">&nbsp;</a>');
          div.find('a.sense_settings').click(sense_settings);
        });
  }

  function init_console_widgets(console_url) {
    var base_url = window.location.href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
      .replace(/^http:/, 'https:');

    jQuery('div.console_widget')
      .each(
        function() {
          var div = jQuery(this);
          var snippet = div.attr('data-snippet');
          div
            .html('<a class="console_widget" target="console" '
              + 'title="Open snippet in Console" '
              + 'href="'
              + console_url
              + '?load_from='
              + base_url
              + snippet
              + '">View in Console</a>'
              + '<a class="console_settings" title="Configure Console URL">&nbsp;</a>');
          div.find('a.console_settings').click(console_settings);
        });
  }

  function sense_settings(e) {
    e.stopPropagation();
    if (jQuery('#sense_settings').length > 0) {
      return;
    }

    var div = jQuery('<div id="sense_settings">'
      + '<form>'
      + '<label for="sense_url">Enter the URL of the Sense editor:</label>'
      + '<input id="sense_url" type="text" value="'
      + sense_url
      + '" />'
      + '<button id="save_url"    type="button">Save</button>'
      + '<button id="reset_url"   type="button">Default Sense URL</button>'
      + '<button id="reset_url_1" type="button">Default Sense v1 URL (Marvel)</button>'
      + '<p>Or install <a href="https://www.elastic.co/guide/en/sense/current/installing.html">'
      + 'the Sense 2 editor'
      + '</a>.</p>'
      + '</form></div>');
    jQuery('body').prepend(div);

    div.find('#save_url').click(function(e) {
      var new_url = jQuery('#sense_url').val() || default_sense_url;
      if (new_url === default_sense_url) {
        Cookies.set('sense_url', '');
      } else {
        Cookies.set('sense_url', new_url, {expires: 365, path: ''});
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
    div.find('#reset_url_1').click(function(e) {
      jQuery('#sense_url').val(default_sense_url_marvel);
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
      + '<label for="console_url">Enter the URL of the Console editor:</label>'
      + '<input id="console_url" type="text" value="'
      + console_url
      + '" />'
      + '<button id="save_url"    type="button">Save</button>'
      + '<button id="reset_url"   type="button">Default Console URL</button>'
      + '<p>Or install <a href="https://www.elastic.co/guide/en/kibana/master/setup.html">'
      + 'Kibana'
      + '</a>.</p>'
      + '</form></div>');
    jQuery('body').prepend(div);

    div.find('#save_url').click(function(e) {
      var new_url = jQuery('#console_url').val() || default_console_url;
      if (new_url === default_console_url) {
        Cookies.set('console_url', '');
      } else {
        Cookies.set('console_url', new_url,{expires: 365, path: ''});
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
    title.find('select').change(
      function(e) {
        var url = location.href;
        var version = title.find('option:selected').val();
        var url = location.href.replace(/[^\/]+\/+([^\/]+\.html)/, version
          + "/$1");

        // If page exists in new version then redirect, otherwise alert
        jQuery.get(url).done(function() {
          location.href = url;
        }).fail(
          function() {
            v_selected.attr('selected', 'selected');
            alert('This page is not available in the '
              + version
              + ' version of the docs.')
          });
      });
  }

  function init_headers() {
    // Add on-this-page block
    this_page.append('<h2>On this page</h2>');
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
    jQuery('div.toc a[href="' + page + '"]') //
    .parentsUntil('ul.toc', 'li.collapsible').addClass('show');
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

