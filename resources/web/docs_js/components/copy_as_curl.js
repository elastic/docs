import {$, Cookies} from "../deps";

export const mount_console = ({mount_point,
                              config_on_click,
                              lang_strings,
                              widget_title,
                              widget_text,
                              console_title,
                              base_url,
                              url} = opts) => {
  const tpl = `
    <a class="sense_widget copy_as_curl" data-curl-host="localhost:9200">
      ${lang_strings('Copy as cURL')}
    </a>
    <a class="console_widget"
       target="console"
       title="${lang_strings(widget_title)}"
       href="${url}?load_from=${base_url}${snippet}">${lang_strings(widget_text)}</a>
    <a class="console_settings" title="${lang_strings(console_title)}">&nbsp;</a>
  `;

  const snippet = mount_point.attr('data-snippet');

  mount_point.html(tpl);
  mount_point.find('a.console_settings').click(config_on_click);

  return mount_point;
}
