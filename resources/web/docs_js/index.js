import AlternativeSwitcher from "./components/alternative_switcher";
import ConsoleWidget from "./components/console_widget";
import Modal from "./components/modal";
import mount from "./components/mount";
import {switchTabs} from "./components/tabbed_widget";
import {Cookies, $} from "./deps";
import {lang_strings} from "./localization";
import store from "./store";
import * as utils from "./utils.js";
import PR from "../lib/prettify/prettify";
import "./prettify/lang-asciidoc";
import "./prettify/lang-console";
import "../lib/prettify/lang-sql";
import "../lib/prettify/lang-yaml";

// Add support for <details> in IE and the like
import "../../../../../node_modules/details-polyfill";

// Add support for URLSearchParams Web API in IE
import "../../../../../node_modules/url-search-params-polyfill";

export function init_headers(sticky_content, lang_strings) {
  // Add on-this-page block
  var this_page = $('<div id="this_page"></div>').prependTo(sticky_content);
  this_page.append('<p id="otp" class="aside-heading">' + lang_strings('On this page') + '</p>');
  var ul = $('<ul></ul>').appendTo(this_page);
  var items = 0;
  var baseHeadingLevel = 0;

  $('#guide a[id]:not([href])').each(
    function(i, el) {
      // Make headers into real links for permalinks
      this.href = '#' + this.id;

      // Extract on-this-page headers, without embedded links
      var title_container = $(this).parent('h1,h2,h3,h4').clone();
      if (title_container.length > 0) {
        // Assume initial heading is an H1, but adjust if it's not
        let hLevel = 0;
        if ($(this).parent().is("h2")){
          hLevel = 1;
        } else if ($(this).parent().is("h3")){
          hLevel = 2;
        } else if ($(this).parent().is("h4")){
          hLevel = 3;
        }

        // Set the base heading level for the page to the title page level + 1
        // This ensures top level headings aren't nested
        if (i === 0){
          baseHeadingLevel = hLevel + 1;
        }

        // Build list items for all headings except the page title
        if (0 < items++) {
          title_container.find('a,.added,.coming,.deprecated,.experimental')
            .remove();
          var text = title_container.html();
          const adjustedLevel = hLevel - baseHeadingLevel;
          const li = '<li id="otp-text-' + i + '" class="otp-text heading-level-' + adjustedLevel + '"><a href="#' + this.id + '">' + text + '</a></li>';
          ul.append(li);
        }
      }
    });
  if (items < 2) {
    this_page.remove();
  }
}

export function init_console_widgets() {
  $('div.console_widget').each(function() {
    const div         = $(this),
          snippet     = div.attr('data-snippet'),
          consoleText = div.prev().text() + '\n';

    return mount(div, ConsoleWidget, {setting: "console",
                                      url_label: 'Enter the URL of the Console editor',
                                      view_in_text: 'View in Console',
                                      configure_text: 'Configure Console URL',
                                      addPretty: true,
                                      consoleText,
                                      snippet});
  });
}

export function init_sense_widgets() {
  $('div.sense_widget').each(function() {
    const div         = $(this),
          snippet     = div.attr('data-snippet'),
          consoleText = div.prev().text() + '\n';

    return mount(div, ConsoleWidget, {setting: "sense",
                                      url_label: 'Enter the URL of the Sense editor',
                                      view_in_text: 'View in Sense',
                                      configure_text: 'Configure Sense URL',
                                      addPretty: true,
                                      consoleText,
                                      snippet});
  });
}

function init_kibana_widgets() {
  $('div.kibana_widget').each(function() {
    const div         = $(this),
          snippet     = div.attr('data-snippet'),
          consoleText = div.prev().text() + '\n';

    return mount(div, ConsoleWidget, {setting: "kibana",
                                      isKibana: true,
                                      url_label: 'Enter the URL of Kibana',
                                      configure_text: 'Configure Kibana URL',
                                      consoleText,
                                      snippet});
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
    .change(function(e) {
      var version = $(e.target).find('option:selected').val();
      if (version === "other") {
        $("#other_versions").show();
        $("#live_versions").hide();
        return;
      }
      utils.get_current_page_in_version(version).fail(function() {
        v_selected.attr('selected', 'selected');
        alert(lang_strings('This page is not available in the docs for version:')
              + version);
      });
    });
}

function highlight_otp() {
  let visibileHeadings = []
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      const id = entry.target.getAttribute('id');
      let element = document.querySelector(`#sticky_content #this_page a[href="#${id}"]`);
      let itemId = $(element).parent().attr('id')
      if (entry.intersectionRatio > 0){
        visibileHeadings.push(itemId);
      } else {
        const position = visibileHeadings.indexOf(itemId);
        visibileHeadings.splice(position, position + 1)
      }
      if (visibileHeadings.length > 0) {
        visibileHeadings.sort()
        // Remove existing active classes
        $('a.active').removeClass("active");
        // Add active class to the first visible heading
        $('#' + visibileHeadings[0] + ' > a').addClass('active')
      }
    })
  })

  document.querySelectorAll('#guide a[id]').forEach((heading) => {
    console.log("heading", heading);
    observer.observe(heading);
  })
}

// Main function, runs on DOM ready
$(function() {
  var lang = $('section#guide[lang]').attr('lang') || 'en';

  const default_kibana_url  = 'http://localhost:5601',
        default_console_url = default_kibana_url + '/app/kibana#/dev_tools/console',
        default_sense_url   = default_kibana_url + '/app/sense/',
        default_ess_url     = 'http://localhost:5601', // localhost is wrong, but we'll enhance this later
        default_ece_url     = 'http://localhost:5601',
        base_url            = utils.get_base_url(window.location.href),
        LangStrings         = lang_strings(lang);

  // Capturing the various global variables into the store
  const initialStoreState = {
    settings: {
      language: lang,
      langStrings: LangStrings,
      baseUrl: base_url,
      kibana_url: Cookies.get("kibana_url") || default_kibana_url,
      kibana_curl_host: Cookies.get("kibana_curl_host") || "localhost:5601",
      kibana_curl_user: Cookies.get("kibana_curl_user"),
      kibana_curl_password: "$KIBANAPASS",
      console_url: Cookies.get("console_url") || default_console_url,
      console_curl_host: Cookies.get("console_curl_host") || "localhost:9200",
      console_curl_user: Cookies.get("console_curl_user"),
      console_curl_password: "$ESPASS",
      sense_url: Cookies.get("sense_url") || default_sense_url,
      sense_curl_host: Cookies.get("sense_curl_host") || "localhost:9200",
      sense_curl_user: Cookies.get("sense_curl_user"),
      sense_curl_password: "$ESPASS",
      ess_url: Cookies.get("ess_url") || default_ess_url,
      ess_curl_host: Cookies.get("ess_curl_host") || "localhost:5601",
      ess_curl_user: Cookies.get("ess_curl_user"),
      ess_curl_password: "$CLOUD_PASS",
      ece_url: Cookies.get("ece_url") || default_ece_url,
      ece_curl_host: Cookies.get("ece_curl_host") || "localhost:5601",
      ece_curl_user: Cookies.get("ece_curl_user"),
      ece_curl_password: "$ECE_PASS",
      consoleAlternative: Cookies.get('consoleAlternative') || "console",
    },
    /*
     * Grab the initial state that we know how to deal with from the page.
     * Rather than grab *everything* we grab the keys we can reduce to prevent
     * things from falling over when an out of date version of the js sees new
     * initial state. This wouldn't be a thing if we could bust the cache at
     * will but, at this point, we can't.
     */
    alternatives: window.initial_state.alternatives,
  };

  // first call to store initializes it
  store(initialStoreState);

  // One modal component for N mini-apps
  mount($('body'), Modal);

  AlternativeSwitcher(store());

  var sticky_content = $('#sticky_content'); // Move rtp container to top right and make visible
  var left_col = $('#left_col'); // Move OTP to top left

  $('.page_header > a[href="../current/index.html"]').click(function() {
    utils.get_current_page_in_version('current');
  });

  // Enable Sense widget
  init_sense_widgets();
  init_console_widgets();
  init_kibana_widgets();
  $("div.ess_widget").each(function() {
    const div         = $(this),
          snippet     = div.attr('data-snippet'),
          consoleText = div.prev().text() + '\n';

    return mount(div, ConsoleWidget, {
      setting: "ess",
      url_label: 'Enter the endpoint URL of the Elasticsearch Service',
      configure_text: 'Configure the Elasticsearch Service endpoint URL',
      consoleText,
      snippet
    });
  });
  $("div.ece_widget").each(function() {
    const div         = $(this),
          snippet     = div.attr('data-snippet'),
          consoleText = div.prev().text() + '\n';

    return mount(div, ConsoleWidget, {
      setting: "ece",
      url_label: 'Enter the endpoint URL of Elastic Cloud Enterprise',
      configure_text: 'Configure the Elastic Cloud Enterprise endpoint URL',
      consoleText,
      snippet
    });
  });

  var div = $('div.toc');

  // Fetch toc.html unless there is already a .toc on the page
  if (div.length == 0 && $('#guide').find('div.article,div.book').length == 0) {
    var url = location.href.replace(/[^\/]+$/, 'toc.html');
    var toc = $.get(url, {}, function(data) {
      left_col.append(data);
      init_toc(LangStrings);
      utils.open_current(location.pathname);
    }).always(function() {
      init_headers(sticky_content, LangStrings);
      highlight_otp();
    });
  } else {
    init_toc(LangStrings);
  }

  PR.prettyPrint();

  // Setup hot module replacement for css if we're in dev mode.
  if (module.hot) {
    var hotcss = document.createElement('script');
    hotcss.setAttribute('src', '/guide/static/styles.js');
    document.head.appendChild(hotcss);
  }

  // For the private docs repositories, the edit button is hidden
  // unless there is an '?edit' in the query string or hash.

  if (new URLSearchParams(window.location.search).has('edit')
      || window.location.hash.indexOf('?edit') > -1) {

    $('a.edit_me_private').show();
  }

  // Test comment used to detect unminifed JS in tests
});

// Tabbed widgets
switchTabs();
