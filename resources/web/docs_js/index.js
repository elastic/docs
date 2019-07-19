import Cookies from "js-cookie";
import {get_base_url} from "./utils.js";
import {lang_strings} from "./localization.js";
import * as events from "./events.js";
import $ from "jquery";

const default_kibana_url = 'http://localhost:5601',
      default_console_url = default_kibana_url + '/app/kibana#/dev_tools/console',
      default_sense_url = default_kibana_url + '/app/sense/';

// Global variables -- TODO improve
var kibana_url;
var console_url;
var sense_url;

export function init_headers(right_col, lang_strings) {
  // Add on-this-page block
  var this_page = $('<div id="this_page"></div>').prependTo(right_col);
  this_page.append('<h2>' + lang_strings('On this page') + '</h2>');
  var ul = $('<ul></ul>').appendTo(this_page);
  var items = 0;

  $('#guide a[id]').each(
    function() {
      // Make headers into real links for permalinks
      this.href = '#' + this.id;

      // Extract on-this-page headers, without embedded links
      var title_container = $(this).parent('h1,h2,h3').clone();
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

export function console_settings(lang_strings) {
  if ($('#console_settings').length > 0) {
    return;
  }

  var div = $('<div id="console_settings">'
    + '<form>'
    + '<label for="console_url">'
    + lang_strings('Enter the URL of the Console editor')
    + '</label>'
    + '<input id="console_url" type="text" value="'
    + console_url
    + '" />'
    + '<button id="save_url"    type="button">'
    + lang_strings('Save')
    + '</button>'
    + '<button id="reset_url"   type="button">'
    + lang_strings('Default Console URL')
    + '</button>'
    + '<p>'
    + lang_strings('Or install Kibana')
    + '</p>'
    + '</form></div>');
  $('body').prepend(div);

  div.find('#save_url').click(function(e) {
    var new_url = $('#console_url').val() || default_console_url;
    if (new_url === default_console_url) {
      Cookies.set('console_url', '');
    } else {
      Cookies.set('console_url', new_url, {
        expires : 365
      });
    }
    console_url = new_url;
    init_console_widgets(console_url, lang_strings);
    div.remove();
    e.stopPropagation();
  });
  div.find('#reset_url').click(function(e) {
    $('#console_url').val(default_console_url);
    e.stopPropagation();
  });
}

export function init_console_widgets(console_url, lang_strings) {
  var base_url = get_base_url(window.location.href);

  $('div.console_widget').each(function() {
    var div = $(this);
    var snippet = div.attr('data-snippet');
    div.html('<a class="sense_widget copy_as_curl" data-curl-host="localhost:9200">'
      + lang_strings('Copy as cURL')
      + '</a>'
      + '<a class="console_widget" target="console" '
      + 'title="'
      + lang_strings('Open snippet in Console')
      + '" '
      + 'href="'
      + console_url
      + '?load_from='
      + base_url
      + snippet
      + '">'
      + lang_strings('View in Console')
      + '</a>'
      + '<a class="console_settings" title="'
      + lang_strings('Configure Console URL')
      + '">&nbsp;</a>');
    div.find('a.console_settings').click(function(_) {
      console_settings(lang_strings);
    });
  });

  $('#guide').on('click', 'a.copy_as_curl', events.copy_as_curl(lang_strings));
}

export function init_sense_widgets(sense_url, lang_strings) {
  var base_url = get_base_url(window.location.href);

  $('div.sense_widget').each(function() {
    var div = $(this);
    var snippet = div.attr('data-snippet');
    div.html('<a class="sense_widget copy_as_curl" data-curl-host="localhost:9200">'
      + lang_strings('Copy as cURL')
      + '</a>'
      + '<a class="sense_widget" target="sense" '
      + 'title="'
      + lang_strings('Open snippet in Sense')
      + '" '
      + 'href="'
      + sense_url
      + '?load_from='
      + base_url
      + snippet
      + '">'
      + lang_strings('View in Sense')
      + '</a>'
      + '<a class="sense_settings" title="'
      + lang_strings('Configure Sense URL')
      + '">&nbsp;</a>');

    div.find('a.sense_settings').click(function(_) {
      sense_settings(lang_strings);
    });
  });
}

function init_kibana_widgets(kibana_url, lang_strings) {
  var base_url = get_base_url(window.location.href);

  $('div.kibana_widget').each(function() {
    var div = $(this);
    var snippet = div.attr('data-snippet');
    div.html('<a class="kibana_widget copy_as_curl" data-curl-host="'
      + kibana_url
      + '" data-kibana="true">'
      + lang_strings('Copy as cURL')
      + '</a>'
      + '<a class="kibana_settings" title="'
      + lang_strings('Configure Kibana URL')
      + '">&nbsp</a>'
    );

    div.find('a.kibana_settings').click(function(_) {
      kibana_settings(lang_strings)
    });
  });
}


function sense_settings(lang_strings) {
  if ($('#sense_settings').length > 0) {
    return;
  }

  var div = $('<div id="sense_settings">'
    + '<form>'
    + '<label for="sense_url">'
    + lang_strings('Enter the URL of the Sense editor')
    + '</label>'
    + '<input id="sense_url" type="text" value="'
    + sense_url
    + '" />'
    + '<button id="save_url" type="button">'
    + lang_strings('Save')
    + '</button>'
    + '<button id="reset_url" type="button">'
    + lang_strings('Default Sense URL')
    + '</button>'
    + '<p>'
    + lang_strings('Or install Sense2')
    + '</p>'
    + '</form></div>');

  $('body').prepend(div);

  div.find('#save_url').click(function(e) {
    var new_url = $('#sense_url').val() || default_sense_url;
    if (new_url === default_sense_url) {
      Cookies.set('sense_url', '');
    } else {
      Cookies.set('sense_url', new_url, {
        expires : 365
      });
    }
    sense_url = new_url;
    init_sense_widgets(sense_url, lang_strings);
    div.remove();
    e.stopPropagation();
  });

  div.find('#reset_url').click(function(e) {
    $('#sense_url').val(default_sense_url);
    e.stopPropagation();
  });
}


function kibana_settings(lang_strings) {
  if ($('#kibana_settings').length > 0) {
    return;
  }

  var div = $('<div id="kibana_settings"><form><label for="kibana_url">'
    + lang_strings('Enter the URL of Kibana')
    + ':</label>'
    + '<input id="kibana_url" type="text" value="'
    + kibana_url
    + '" />'
    + '<button id="save_url" type="button">'
    + lang_strings('Save')
    + '</button>'
    + '<button id="reset_url" type="button">'
    + lang_strings('Default Kibana URL')
    + '</button>'
    + '<p>'
    + lang_strings('Or install Kibana')
    + '</p></form></div>'
  );

  $('body').prepend(div);

  div.find('#save_url').click(function(e) {
    var new_url = $('#kibana_url').val() || default_kibana_url;
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
    $('#kibana_url').val(default_kibana_url);
    e.stopPropagation();
  });
}

function get_current_page_in_version(version) {
  var url = location.href;
  var url = location.href.replace(/[^\/]+\/+([^\/]+\.html)/, version + "/$1");
  return $.get(url).done(function() {
    location.href = url
  });
}

function init_toc(lang_strings) {
  var title = $('#book_title');

  // Make li elements in toc collapsible
  $('div.toc li ul').each(function() {
    var li = $(this).parent();
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
  if ($('.collapsible').length > 0) {
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
  $('div.toc a, #book_title select').click(function(e) {
    e.stopPropagation();
  });

  // Setup version selector
  var v_selected = title.find('select option:selected');
  title
    .find('select')
    .change(function() {
       var version = title.find('option:selected').val();
       get_current_page_in_version(version).fail(function() {
         v_selected.attr('selected', 'selected');
         alert(lang_strings('This page is not available in the docs for version:')
               + version);
       });
     });
}

// Expand ToC to current page (without #)
export function open_current(pathname) {
  var page = pathname.match(/[^\/]+$/)[0];
  var current = $('div.toc a[href="' + page + '"]');
  current.addClass('current_page');
  current.parentsUntil('ul.toc', 'li.collapsible').addClass('show');
}

// Main function, runs on DOM ready
$(function() {
  var lang = $('section#guide[lang]').attr('lang') || 'en';
  var LangStrings = lang_strings(lang);
  var right_col = $('#right_col'); // Move rtp container to top right and make visible

  // Set global variables - TODO improve
  kibana_url  = Cookies.get('kibana_url') || default_kibana_url;
  console_url = Cookies.get('console_url') || default_console_url;
  sense_url   = Cookies.get('sense_url') || default_sense_url;

  $('.page_header > a[href="../current/index.html"]').click(function() {
    get_current_page_in_version('current');
  });

  // Enable Sense widget
  init_sense_widgets(sense_url, LangStrings);
  init_console_widgets(console_url, LangStrings);
  init_kibana_widgets(kibana_url, LangStrings);

  var div = $('div.toc');

  // Fetch toc.html unless there is already a .toc on the page
  if (div.length == 0 && $('#guide').find('div.article,div.book').length == 0) {
    var url = location.href.replace(/[^\/]+$/, 'toc.html');
    var toc = $.get(url, {}, function(data) {
      right_col.append(data);
      init_toc(LangStrings);
      open_current(location.pathname);
    }).always(function() {
      init_headers(right_col, LangStrings);
    });
  } else {
    init_toc(LangStrings);
  }
});
