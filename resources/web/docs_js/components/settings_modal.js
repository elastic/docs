import {$, Cookies} from "../deps";

export function settings_modal({label_text,
                                url_value,
                                button_text,
                                install_text,
                                default_url,
                                cookie_key,
                                update_value,
                                lang_strings} = opts) {
  if ($('#settings_modal').length > 0) {
    return;
  }

  var div = $('<div id="settings_modal">'
    + '<form>'
    + '<label for="url">'
    + label_text
    + '</label>'
    + '<input id="url" type="text" value="'
    + url_value
    + '" />'
    + '<button id="save_url" type="button">'
    + lang_strings('Save')
    + '</button>'
    + '<button id="reset_url" type="button">'
    + button_text
    + '</button>'
    + '<p>'
    + install_text
    + '</p>'
    + '</form></div>');

  $('body').prepend(div);

  div.find('#save_url').click(function(e) {
    var new_url = $('#url').val() || default_url;
    if (new_url === default_url) {
      Cookies.set(cookie_key, '');
    } else {
      Cookies.set(cookie_key, new_url, {
        expires : 365
      });
    }
    update_value(new_url);
    div.remove();
    e.stopPropagation();
  });

  div.find('#reset_url').click(function(e) {
    $('#url').val(default_url);
    e.stopPropagation();
  });
}
