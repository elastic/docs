export function get_base_url(href) {
  return href.replace(/\/[^/?]+(?:\?.*)?$/, '/')
             .replace(/^http:/, 'https:');
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
