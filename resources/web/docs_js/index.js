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
import "../lib/prettify/lang-esql";
import "../lib/prettify/lang-sql";
import "../lib/prettify/lang-yaml";
import items from "../temp/config.js"

// Add support for <details> in IE and the like
import "../../../../../node_modules/details-polyfill";

// Add support for URLSearchParams Web API in IE
import "../../../../../node_modules/url-search-params-polyfill";

// Vocab:
// TOC = table of contents
// OTP = on this page
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
          const li = '<li id="otp-text-' + i + '" class="heading-level-' + adjustedLevel + '"><a href="#' + this.id + '">' + text + '</a></li>';
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
          consoleText = div.prev().text() + '\n',
          langs       = div.attr("class").split(" ").filter(c => c.startsWith("has-")).map(function(string) { return string.substring(4) });

    return mount(div, ConsoleWidget, {setting: "console",
                                      url_label: 'Enter the URL of the Console editor',
                                      view_in_text: 'View in Console',
                                      configure_text: 'Configure Console URL',
                                      addPretty: true,
                                      consoleText,
                                      snippet,
                                      langs});
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
  $('div.toc').attr('id', 'current-toc');

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

// In the OTP, highlight the heading of the section that is
// currently visible on the page.
// If more than one is visible, highlight the heading for the
// section that is higher on the page.
function highlight_otp() {
  let visibleHeadings = []
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      const id = entry.target.getAttribute('id');
      const element = document.querySelector(`#sticky_content #this_page a[href="#${id}"]`);
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


  $('.breadcrumbs').after(`<div class="date-edited">Last updated: Apr 4th, 2023</div>`)
  $('h1').after(`<div class="description">Description to be written</div>`)
  

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

  
  const allHeadings = $('#content').find('h1, h2, h3, h4, h5, h6')
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
      if ($(this).prop('nodeName') === allLevels[0]) $(this).replaceWith(`<h2>${contents}</h2>`);
      if ($(this).prop('nodeName') === allLevels[1]) $(this).replaceWith(`<h3>${contents}</h3>`);
      if ($(this).prop('nodeName') === allLevels[2]) $(this).replaceWith(`<h4>${contents}</h4>`);
    }
    // attrs[attr.nodeName] = attr.nodeValue;
  })

  // Move rtp container to top right and make visible
  var sticky_content = $('#sticky_content');
  // Left column that contains the TOC
  var left_col = $('#left_col');
  // Middle column that contains the main content
  var middle_col = $('#middle_col');
  // Right column that contains the OTP and demand gen content
  var right_col = $('#right_col');
  // Empty column below TOC on small screens so the demand gen content can be positioned under the main content
  var bottom_left_col = $('#bottom_left_col');

  $('.page_header > a[href="../current/index.html"]').click(function(e) {
    e.preventDefault();
    utils.get_current_page_in_version('current').fail(function() {
      location.href = "../current/index.html"
    });
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
    // Style book landing page (no main content, just a TOC and demand gen content)

    // Set the width of the left column to zero
    left_col.removeClass().addClass('col-0');
    bottom_left_col.removeClass().addClass('col-0');
    // Set the width of the middle column (containing the TOC) to 9
    middle_col.removeClass().addClass('col-12 col-lg-9 guide-section');
    // Set the width of the demand gen content to 3
    right_col.removeClass().addClass('col-12 col-lg-3 sticky-top-md h-almost-full-lg');
  }

  const sections = items.map(item => {
    let isActive = item.label === "Observability"
    let subItems = item.items
    if (subItems) {
      subItems = item.items.map(subItem => {
        isActive = subItem.label === "Observability"
        return (
          isActive
          ? `<li><span id="active-book">${subItem.label}</span></li>`
          : `<li><a href="${subItem.link}">${subItem.label}</a></li>`
        )
      })
    }
    return (
      subItems
      ? `<li>${item.label}<ul>${subItems.join('')}</ul></li>`
      : `<li><a href="${item.link}">${item.label}</a></li>`
    )
  })
  
  

  $('#cross-book-nav').prepend(`<div class="book-name">Global nav</div><ul style="margin-top:20px">${sections.join('')}</ul>`)

  $('#book_title').click(function() {
    $('#cross-book-nav').show()
    $("#cross-book-nav").animate({ "left": "+=270px" }, 400 );
    $("#current-toc").animate({ "left": "+=270px" }, 400 );
    
    $('#active-book').click(function() {
      $("#cross-book-nav").animate({ "left": "-=270px" }, 400 );
      $("#current-toc").animate({ "left": "-=270px" }, 400 );
      // $('#cross-book-nav').hide()
    })
  })

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

  // scroll to selected TOC element; if it doesn't exist yet, wait and try again
  // window.width must match the breakpoint of `.sticky-top-md`
  if($(window).width() >= 769){
    var scrollToSelectedTOC = setInterval(() => {
      if ($('.current_page').length) {
          // Get scrollable element
          var container = document.querySelector("#left_col");
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
