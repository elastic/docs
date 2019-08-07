import * as utils from "../utils";
import {lang_strings} from "../localization";

describe("get_base_url", () => {
  test("It leaves the last .html bit off", () => {
    const result = utils.get_base_url("https://localhost:8000/guide/blocks.html");
    expect(result).toEqual("https://localhost:8000/guide/");
  });

  test("It converts http to https", () => {
    const result = utils.get_base_url("http://localhost:8000/a/b/c/d/e/blocks.html");
    expect(result).toEqual("https://localhost:8000/a/b/c/d/e/");
  });
});

describe("getCurlText", () => {
  const langStrings = lang_strings("en");

  test("it adds curl user and password only when both are present", () => {
    const result1 = utils.getCurlText({consoleText: snippetGen(),
                                       curl_host: "http://localhost:9200",
                                       curl_user: "elastic",
                                       langStrings});
    const result2 = utils.getCurlText({consoleText: snippetGen(),
                                       curl_host: "http://localhost:9200",
                                       curl_pw: "elastic",
                                       langStrings});
    const expected = `curl -X GET "http://localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result1).toBe(expected);
    expect(result2).toBe(expected);
  });

  test("it adds user and password when curl_user and curl_password are present", () => {
    const result = utils.getCurlText({consoleText: snippetGen(),
                                      curl_host: "http://localhost:9200",
                                      curl_user: "elastic",
                                      curl_password: "abcde",
                                      langStrings});
    const expected = `curl -X GET -u elastic:abcde "http://localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result).toBe(expected);
  });

  test("it adds the kbn-xsrf header when isKibana is true", () => {
    const result = utils.getCurlText({consoleText: snippetGen(),
                                      isKibana: true,
                                      curl_user: "elastic",
                                      curl_password: "abcde",
                                      curl_host: "http://localhost:9200",
                                      langStrings});
    const expected = `curl -X GET -u elastic:abcde "http://localhost:9200/_search" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result).toBe(expected);
  });

  test("it appends 'pretty' to existing query string", () => {
    const result = utils.getCurlText({consoleText: snippetGen({path: "/_search?q=dev"}),
                                      curl_host: "http://localhost:9200",
                                      langStrings});
    const expected = `curl -X GET "http://localhost:9200/_search?q=dev&pretty" -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result).toBe(expected);
  });


  test("it creates the '?pretty' query string when none is present", () => {
    const result = utils.getCurlText({consoleText: snippetGen({path: "/_search"}),
                                      curl_host: "http://localhost:9200",
                                      langStrings});
    const expected = `curl -X GET "http://localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result).toBe(expected);
  });

  test("it adds '-I' when the method is 'HEAD'", () => {
    const result = utils.getCurlText({consoleText: snippetGen({method: "HEAD"}),
                                      curl_host: "http://localhost:9200",
                                      langStrings});
    const expected = `curl -I "http://localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result).toBe(expected);
  });

  test("it adds '-X <method>' when the method is not 'HEAD'", () => {
    const result = utils.getCurlText({consoleText: snippetGen({method: "PUT"}),
                                      curl_host: "http://localhost:9200",
                                      langStrings});
    const expected = `curl -X PUT "http://localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": "foo bar" 
}
'
`;

    expect(result).toBe(expected);
  });


  test("it handles no body", () => {
    const result = utils.getCurlText({consoleText: 'GET /_search?q=dev\n',
                                      curl_host: "http://localhost:9200",
                                      langStrings});
    const expected = 'curl -X GET "http://localhost:9200/_search?q=dev&pretty"\n';
    expect(result).toBe(expected);
  });
});

function snippetGen({method = "GET",
                     path = "/_search"} = {}) {
  const testSnippet = `${method} ${path}
{
    "query": "foo bar" 
}\n`; // trailing new line necessary

  return testSnippet;
};
