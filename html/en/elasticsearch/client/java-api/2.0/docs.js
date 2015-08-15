jQuery(function() {
  // Move rtp container to top right and make visible
  jQuery('#rtpcontainer').prependTo('#guide').show();

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
    if (jQuery('.collapsible').length > 0 ) {
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
        var url = location.href.replace(/[^\/]+(\/[^\/]+\.html)/, version
          + "$1");

        // If page exists in new version then redirect, otherwise alert
        jQuery.get(url).done(function() {
          location.href = url;
        }).fail(
          function() {
            v_selected.attr('selected', 'selected');
            alert('This page is not available in the ' + version
              + ' version of the docs.')
          });
      });
  }

  function init_headers() {
    // Add on-this-page block
    jQuery('.titlepage').first().after(
      '<div id="this_page"><h2>On this page</h2><ul></ul></div>');
    var items = 0;
    var ul = jQuery('#this_page ul');

    jQuery('#guide a[id]').each(
      function() {
        // Make headers into real links for permalinks
        this.href = '#' + this.id;

        // Extract on-this-page headers, without embedded links
        var title_container = jQuery(this).parent('h1,h2,h3').clone();
        if (title_container.length > 0) {
          // Exclude page title
          if (0 < items++) {
            title_container.find('a,.added,.coming,.deprecated,.experimental').remove();
            var text = title_container.html();
            ul.append('<li><a href="#' + this.id + '">' + text + '</a></li>');
          }
        }
      });
    if (items < 2) {
      jQuery('#this_page').remove();
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
  if (div.length == 0  && jQuery('#guide').children('.article,.book').length == 0) {
    var url = location.href.replace(/[^\/]+$/, 'toc.html');
    var toc = jQuery.get(url, {}, function(data) {
      jQuery('.titlepage').first().after(data);
      init_toc();
      open_current();
    }).always(init_headers);
  } else {
    init_toc();
  }
});
