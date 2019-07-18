export function get_base_url(href) {
  return href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
             .replace(/^http:/, 'https:');
}

export function lang_strings(lang) {
  if (lang === 'en') {
    return {
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
    return {
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
