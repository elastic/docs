import AlternativeSwitcher from "./components/alternative_switcher";
import ConsoleWidget from "./components/console_widget";
import FeedbackModal from './components/feedback_modal';
import FeedbackWidget from './components/feedback_widget';
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
import "../lib/prettify/lang-esql";
import "../lib/prettify/lang-sql";
import "../lib/prettify/lang-yaml";

// Add support for <details> in IE and the like
import "../../../../../node_modules/details-polyfill";

// Add support for URLSearchParams Web API in IE
import "../../../../../node_modules/url-search-params-polyfill";

export function init_landing_page() {
  // Because of the nature of the injected links, we need to adjust the layout to
  // Fit into two columns on the landing page.

  // Select all top-level h3 elements within the #content div
  $('.docs-landing div#content > h2').each(function() {
    var $siblingDiv = $(this).next('div.ulist.itemizedlist');

    // Wrap the h3 and its sibling div in a div with class docs-link-section
    $(this).add($siblingDiv).wrapAll('<div class="docs-link-section"></div>');
  });

  // Select the last .docs-link-section
  var $lastDocsLinkSection = $('.docs-link-section:last');

  // Remove it from its current position
  $lastDocsLinkSection.detach();

  // Append it outside of the div#content element
  $lastDocsLinkSection.addClass('legacy-docs hidden').insertAfter('div#content');

  $lastDocsLinkSection.find('h2').append('<span class="toggle-icon">&#9660;</span>');

  // Click handler to toggle visibility
  $lastDocsLinkSection.find('h2').on('click', function() {
    $lastDocsLinkSection.toggleClass('hidden');
  });

  // Move "need help" section to the bottom of the page
  $('#bottomContent').insertAfter($lastDocsLinkSection).show();
}

export function init_headers(right_col, lang_strings) {
  // Add "On this page" (table of contents)
  const version_selector = right_col.find('#version-selectors-full')
  let this_page = $('<div id="on-this-page-container"></div>').insertAfter(version_selector);
  this_page.append('<p id="otp" class="aside-heading">' + lang_strings('On this page') + '</p>');
  this_page.addClass('not-empty');
  var ul = $('<ul></ul>').appendTo(this_page);
  var items = 0;
  var baseHeadingLevel = 0;

  $('main#page-template-inner').find('h1,h2,h3,h4').each(
    function(i) {
      const link = $(this).find('a')[0]
      // Make headers into real links for permalinks
      if (link) {
        link.href = '#' + link.id;
        // Extract on-this-page headers, without embedded links
        var title_container = $(link).parent('h1,h2,h3,h4').clone();
        if (title_container.length > 0) {
          // Assume initial heading is an H1, but adjust if it's not
          let hLevel = 0;
          if ($(link).parent().is("h2")){
            hLevel = 1;
          } else if ($(link).parent().is("h3")){
            hLevel = 2;
          } else if ($(link).parent().is("h4")){
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
            const li = '<li id="otp-text-' + i + '" class="heading-level-' + adjustedLevel + '"><a href="#' + link.id + '">' + text + '</a></li>';
            ul.append(li);
          }
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
          consoleText = div.prev().text() + '\n',
          langs       = div.attr("class").split(" ").filter(c => c.startsWith("has-")).map(function(string) { return string.substring(4) });

    return mount(div, ConsoleWidget, {setting: "console",
                                      url_label: 'Console URL',
                                      view_in_text: 'Try in Elastic',
                                      configure_text: 'Configure Console URL',
                                      addPretty: true,
                                      consoleText,
                                      snippet,
                                      langs});
  });
}

export function init_feedback_widget() {
  mount($('#feedbackWidgetContainer'), FeedbackWidget);
  $('.feedbackButton').click(function () {
    const isLiked = $(this).hasClass('feedbackLiked');
    $(this).addClass('isPressed');
    mount($('#feedbackModalContainer'), FeedbackModal, { isLiked: isLiked });
  });
}

export function init_sense_widgets() {
  $('div.sense_widget').each(function() {
    const div         = $(this),
          snippet     = div.attr('data-snippet'),
          consoleText = div.prev().text() + '\n';

    return mount(div, ConsoleWidget, {setting: "sense",
                                      url_label: 'Sense URL',
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

  // Clicking links or the version selector shouldn't fold/expand
  $('div.toc a, #book_title select').click(function(e) {
    e.stopPropagation();
  });
}

// Set up the version selector for interaction
function init_version_selector (lang_strings) {
  const version_selectors = $("div#wrap_live_versions")
  const other_version_selectors = $("div#wrap_other_versions")

  // When the page is loaded, if the value of the live version selector
  // is 'other', show the other version selector and related text
  if (version_selectors.find('select option:selected').val() === 'other') {
    $("#other_versions_text").show();
    $("#wrap_other_versions").show();
  }

  $(version_selectors).find('select').change(function(e) {
    onVersionChange(e.target)
  })

  $(other_version_selectors).find('select').change(function(e) {
    onVersionChange(e.target)
  })

  function onVersionChange (target) {
    const versions_list = $.makeArray($(target).find('option')).map(opt => opt.value)
    const v_selected = $(target).find('select option:selected');
    const version = $(target).find('option:selected').val();
    $.makeArray($("#wrap_other_versions").find('option')).forEach(opt => {
      if (versions_list.includes(opt.value)) {
        $(`#wrap_other_versions > select > option[value="${opt.value}"]`).remove();
      }
    })

    if (version === "other") {
      $("#other_versions_text").show();
      $("#wrap_other_versions").show();
      return;
    } else {
      $("#other_versions_text").hide();
      $("#wrap_other_versions").hide();
    }
    utils.get_current_page_in_version(version).fail(function() {
      v_selected.attr('selected', 'selected');
      alert('This page is not available in the docs for version:' + version);
    });
  }
}

// In the OTP, highlight the heading of the section that is
// currently visible on the page.
// If more than one is visible, highlight the heading for the
// section that is higher on the page.
function highlight_otp() {
  let visibleHeadings = []
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      const id = entry.target.getAttribute('id');
      const element = document.querySelector(`#on-this-page-container a[href="#${id}"]`);
      const itemId = $(element).parent().attr('id')
      // All heading elements have an `entry` (even the title).
      // The title does not exist in the OTP, so we must exclude it.
      // Checking for the existence of `itemId` ensures we don't parse elements that don't exist.
      if (itemId){
        const itemNumber = parseInt(itemId.match(/\d+/)[0], 10);
        if (entry.intersectionRatio > 0){
          visibleHeadings.push(itemNumber);
        } else {
          const position = visibleHeadings.indexOf(itemNumber);
          visibleHeadings.splice(position, 1)
        }
        if (visibleHeadings.length > 0) {
          visibleHeadings.sort((a, b) => a - b)
          // Remove existing active classes
          $('a.active').removeClass("active");
          // Add active class to the first visible heading
          $('#otp-text-' + visibleHeadings[0] + ' > a').addClass('active')
        }
      }
    })
  })

  document.querySelectorAll('#guide a[id]').forEach((heading) => {
    observer.observe(heading);
  })
}

function getUtm() {
  const qs = new Proxy(new URLSearchParams(window.location.search), {
    get: (searchParams, prop) => searchParams.get(prop),
  })

  return {
    'utm_source': qs['utm_source'],
    'utm_medium': qs['utm_medium'],
    'utm_campaign': qs['utm_campaign'],
    'utm_content': qs['utm_content'],
    'utm_term': qs['utm_term'],
    'utm_id': qs['utm_id'],
  }
}

function getCookie(cookieName) {
  let cookie = document.cookie
    .split('; ')
    .find(row => row.startsWith(cookieName + '='));
  if (cookie == undefined) {
    return undefined
  }
  return cookie.split('=')[1]
}

function getEuid() {
  return getCookie('euid')
}

// Main function, runs on DOM ready
$(function() {

  var lang = $('section#guide[lang]').attr('lang') || 'en';

  const default_kibana_url  = 'http://localhost:5601',
        default_base_path   = '/zzz', // Since the original implementation, the base path was added and most users use it.
        default_console_url = default_kibana_url + default_base_path + '/app/kibana#/dev_tools/console',
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

  const allHeadings = $('main').find('h1, h2, h3, h4, h5, h6')
  let allLevels = []
  allHeadings.each(function(index) {
    if (index === 0) return
    if (!allLevels.includes($(this).prop('nodeName'))) allLevels.push($(this).prop('nodeName'))
  })

  allHeadings.each(function(index) {
    const currentHeading = $(this)
    const contents = currentHeading.prop('innerHTML')
    if (index === 0) {
      currentHeading.replaceWith(`<h1>${contents}</h1>`);
    } else {
      if (allLevels[0] && ($(this).prop('nodeName') === allLevels[0])) {
        $(this).replaceWith(`<h2>${contents}</h2>`);
      }
      if (allLevels[1] && ($(this).prop('nodeName') === allLevels[1])) {
        $(this).replaceWith(`<h3>${contents}</h3>`);
      }
      if (allLevels[2] && ($(this).prop('nodeName') === allLevels[2])) {
        $(this).replaceWith(`<h4>${contents}</h4>`);
      }
      if (allLevels[3] && ($(this).prop('nodeName') === allLevels[3])) {
        $(this).replaceWith(`<h5>${contents}</h5>`);
      }
      if (allLevels[4] && ($(this).prop('nodeName') === allLevels[4])) {
        $(this).replaceWith(`<h6>${contents}</h6>`);
      }
    }
  })
  // If breadcrumbs contain a dropdown (e.g. APM, ECS Logging)
  // handle interaction with the dropdown
  if ($('#related-products')) {
    // Select-type element used to reveal options
    const dropDownAnchor = $('#related-products > .dropdown-anchor')
    // Popover-type element containing options
    const dropDownContent = $('#related-products > .dropdown-content')
    // Toggle the visibility of the popover on click
    dropDownAnchor.click(function (e) {
      e.preventDefault();
      dropDownContent.toggleClass('show')
    });
    // Toggle the visibility of the popover on enter
    dropDownAnchor.keypress(function (e) {
      if (e.which == 13) {
        dropDownContent.toggleClass('show')
      }
    });
    // Close the popover when clicking outside it
    $(document).mouseup(function(e) {
      if (
        dropDownContent.hasClass("show")
        && !dropDownAnchor.is(e.target)
        && !dropDownContent.is(e.target)
        && dropDownContent.has(e.target).length === 0
      ) {
        dropDownContent.removeClass("show")
      }
    })
    // Bold the item in the popover that represents
    // the current book
    const currentBookTitle = dropDownAnchor.text()
    const items = dropDownContent.find("li")
    items.each(function(i) {
      if (items[i].innerText === currentBookTitle) {
        const link = items[i].children[0]
        link.style.fontWeight = 700
      }
    })
  }

  // Left column that contains the TOC
  var left_col = $('#sidebar');
  // Middle column that contains the main content
  var middle_col = $('#main-content');
  // Right column that contains the OTP and demand gen content
  var right_col = $('#right-sidebar');
  // Empty column below TOC on small screens so the demand gen content can be positioned under the main content
  var bottom_left_col = $('#bottom_left_col');

  $('.page_header > a[href="../current/index.html"]').click(function(e) {
    e.preventDefault();
    utils.get_current_page_in_version('current').fail(function() {
      location.href = "../current/index.html"
    });
  });

  $('#doc-site-header-links-tooltip-anchor').click(function() {
    $('#mobile-site-nav-header-tooltip').toggle()
  })

  $('#mobile-collection-navigation').click(function() {
    $('#inner-sidebar').toggle()
  })

  // Enable Sense widget
  init_sense_widgets();
  init_console_widgets();
  init_kibana_widgets();
  init_feedback_widget();
  init_landing_page();

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

  $('div.console_code_copy').each(function () {
    const $copyButton = $(this);
    const langText = $copyButton.next().text();

    $copyButton.on('click', function () {
      utils.copyText(langText, lang_strings);
      $copyButton.addClass('copied');
      setTimeout(function () {
        $copyButton.removeClass('copied')
      }, 3000);
    });
  });

  /** Temporary hack for custom landing pages that include TOC */
  const customLandingPage = $('#preamble')

  if (customLandingPage.length) {
    window.addEventListener("DOMContentLoaded", (event) => {
      // Update layout
      $('#doc-article').css('flex-direction', 'column');
      $('#main-content').css('width', '100%');
      $('#on-this-page-container').hide();

      // Add breadcrumbs
      $('div.navheader').empty()
      $('div.navheader').append('<div class="breadcrumb-container"><div class="breadcrumbs"><span class="breadcrumb-link"><a href="/guide/"><span class="home-link"></span></a></span></div><div id="version-selectors-mid"></div></div>');

      // Reposition version selector
      const version_selectors = $('div#version-selectors');
      $('div#version-selectors-full').empty();
      $('div#version-selectors-mid').append(version_selectors);
      if ($(window).width() <= 766) {
        $('div#version-selectors-mid').empty();
        $('div#version-selectors-mobile').append(version_selectors);
      }

      const toc = $("#content div.toc")
      $('#doc-sidebar').append(toc)
    });
  }


  // Fetch toc.html unless there is already a .toc on the page
  var tocDiv = $('ul.toc');
  if (tocDiv.length === 0) {
    var url = location.href.replace(/[^\/]+$/, 'toc.html');
    $.get(url, {}, function(data) {
      // Break into individual pieces
      const html = $($.parseHTML(data))
      const version_selectors = $(html).find('div#version-selectors')
      const book_title = $(html).find('div#book_title')
      const book_title_text = book_title.text()
      const toc = $(html).find('ul.toc')

      // Add table of contents
      $('div#collection-selector').append(book_title)
      $('nav#doc-sidebar').append(toc)
      init_toc();

      $('#mobile-collection-navigation-text').text(`${book_title_text} navigation`)

      // Add version selector
      if ($(window).width() < 769) {
        $('div#version-selectors-mobile').append(version_selectors);
      } else if ($(window).width() >= 769 && $(window).width() < 992) {
        $('div#version-selectors-mid').append(version_selectors);
      } else {
        $('div#version-selectors-full').append(version_selectors);
      }

      init_version_selector();

      utils.open_current(location.pathname);
    }).fail(function() {
      // Set the width of the left column to zero
      left_col.removeClass().addClass('col-0');
      bottom_left_col.removeClass().addClass('col-0');
      const sidebar = $('#sidebar')
      $(sidebar).attr('style', 'display:none')
      // Set the width of the middle column (containing the TOC) to 9
      middle_col.removeClass().addClass('guide-section');
      // Set the width of the demand gen content to 3
      right_col.removeClass().addClass('col-12 col-lg-3 sticky-top-md h-almost-full-lg');
    }).always(function() {
      const right_sidebar_container = $('#right-sidebar-container')
      init_headers(right_sidebar_container, LangStrings);
      highlight_otp();
    });
  } else {
    const right_sidebar_container = $('#right-sidebar-container')
    init_headers(right_sidebar_container, LangStrings);
    highlight_otp();
    init_version_selector();
    init_toc();
  }

  PR.prettyPrint();

  // Handle window resizing
  $( window ).on("resize", function() {
    const version_selector = $('#version-selectors')
    // On mobile devices
    if ($(window).width() < 767) {
      // Make sure the version selector does NOT exist outside the mobile nav
      $('div#version-selectors-full') && $('div#version-selectors-full').empty();
      $('div#version-selectors-mid') && $('div#version-selectors-mid').empty();
      // Make sure the the version selector is in the mobile nav
      $('div#version-selectors-mobile').append(version_selector);
      // Hide the left side bar
      $('#inner-sidebar').hide();
    // On mid-size screens
    } else if ($(window).width() >= 767 && $(window).width() < 993) {
      // Make sure the version selector does NOT exist in the right side nav or the mobile nav
      $('div#version-selectors-full') && $('div#version-selectors-full').empty();
      $('div#version-selectors-mobile') && $('div#version-selectors-mobile').empty();
      // Make sure the the version selector is in the middle column
      $('div#version-selectors-mid').append(version_selector);
      // Show the left side bar
      $('#inner-sidebar').show();
    // On full laptop/desktop screens
    } else {
      // If it's a custom landing page (which has no right side nav)
      if (customLandingPage.length) {
        // Make sure the version selector does NOT exist in the right side nav or the mobile nav
        $('div#version-selectors-mobile') && $('div#version-selectors-mobile').empty();
        $('div#version-selectors-full') && $('div#version-selectors-full').empty();
        // Make sure the the version selector is in the middle column
        $('div#version-selectors-mid').append(version_selector);
      } else {
        // Make sure the version selector does NOT exist in the right side nav or middle column
        $('div#version-selectors-mobile') && $('div#version-selectors-mobile').empty();
        $('div#version-selectors-mid') && $('div#version-selectors-mid').empty();
        // Make sure the the version selector is in the right side bar
        $('div#version-selectors-full').append(version_selector);
      }
      // Show the left side bar
      $('#inner-sidebar').show();
    }
  })

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

  // scroll to selected TOC element; if it doesn't exist yet, wait and try again
  // window.width must match the breakpoint of `.sticky-top-md`
  if($(window).width() >= 769){
    var scrollToSelectedTOC = setInterval(() => {
      if ($('.current_page').length) {
          // Get scrollable element
          var container = document.querySelector("#sidebar");
          // Get active table of contents element
          var activeItem = document.querySelector(".current_page")
          // If the top of the active item is out of view (or in the bottom 100px of the visible portion of the TOC)
          // scroll so the top of the active item is at the top of the visible portion TOC
          if (container.offsetHeight - 100 <= activeItem.offsetTop) {
            // Scroll to active item
            container.scrollTop = activeItem.offsetTop
          }
        clearInterval(scrollToSelectedTOC);
      }
    }, 150);
  }

  window.dataLayer = window.dataLayer || [];

  const titleParams = document.title.split('|')

  const pageViewData = {
    'event': 'page_view',
    'pagePath': window.location.pathname,
    'pageURL': window.location.href,
    'pageTitle': document.title,
    'pageTemplate': '', // ?
    'team': 'Docs',
    'pageCategory': titleParams[titleParams.length - 2].trim(),
    'hostname': window.location.hostname,
    'canonicalTag': window.location.protocol + '//' + window.location.hostname + window.location.pathname,
    'euid': getEuid(),
    'userId': getCookie('userId'),
    'hashedIP': getCookie('hashedIp'),
    'userAgent': window.navigator.userAgent,
    ...getUtm()
  };
  dataLayer.push(pageViewData);

  // Test comment used to detect unminifed JS in tests
});

// Tabbed widgets
switchTabs();
