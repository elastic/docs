import PR from "../../../lib/prettify/prettify";
import "../../prettify/lang-console";
import dedent from "../../../../../../node_modules/dedent";

const prettyConsole = str => PR.prettyPrintOne(str, "console");
const prettyJs = str => PR.prettyPrintOne(str, "js");

const simpleTests = (pretty, verb, path, params = {}) => {
  test("the verb is a keyword", () => {
    expect(pretty).toContain(`<span class="kwd">${verb}</span>`);
  });
  test("the spacing is plain", () => {
    expect(pretty).toContain(`${verb}</span><span class="pln"> </span>`);
  });
  test("the path is a string", () => {
    const prefix = path.startsWith("/") ? "" : `</span><span class="str">`;
    const prettyPath = path.replace(/\//g, `</span><span class="pun">/</span><span class="str">`);
    expect(pretty).toContain(` ${prefix}${prettyPath}</span>`);
  });
  for (var key in params) {
    test(`the ${key} parameter is correctly highlighted`, () => {
      expect(pretty).toContain(
        `<span class="kwd">${key}</span><span class="pun">=</span><span class="str">${params[key]}</span>`
      );
    });
  }
};

describe("lang-console", () => {
  describe("for a single", () => {
    describe("simple command", () => {
      ["DELETE", "GET", "HEAD", "PATCH", "POST", "PUT"].forEach(verb => {
        describe(`when the verb is ${verb}`, () => {
          const pretty = prettyConsole(`${verb} /twitter/_doc/0`);
          simpleTests(pretty, verb, "/twitter/_doc/0");
        });
      });
      describe("when the path prefixed by /", () => {
        const pretty = prettyConsole("GET /twitter/_doc/0");
        simpleTests(pretty, "GET", "/twitter/_doc/0");
      });
      describe("when the path isn't prefixed by /", () => {
        const pretty = prettyConsole("GET twitter/_doc/0");
        simpleTests(pretty, "GET", "twitter/_doc/0");
      });
      describe("when there are path parameters", () => {
        const pretty = prettyConsole(
          "POST twitter/_search?size=0&q=extra:test&filter_path=hits.total"
        );
        simpleTests(pretty, "POST", "twitter/_search", {
          size: 0,
          q: "extra:test",
          filter_path: "hits.total",
        });
      });
    });
    describe("command with a body", () => {
      describe("when the body has a single line", () => {
        const pretty = prettyConsole(dedent `
          PUT /twitter/_doc/0
          {
            "user" : "kimchy"
          }
        `);
        simpleTests(pretty, "PUT", "/twitter/_doc/0");
        test("highlights the body like js", () => {
          const expected = prettyJs(dedent`
            {
              "user" : "kimchy"
            }
          `);
          expect(pretty).toContain(`0</span><span class="pln">\n</span>${expected}`);
        });
      });
      describe("when the body has a few lines", () => {
        const pretty = prettyConsole(dedent `
          PUT /twitter/_doc/0
          {
            "user" : "kimchy",
            "likes" : 2,
            "message" : "trying out Elasticsearch"
          }
        `);
        simpleTests(pretty, "PUT", "/twitter/_doc/0");
        test("highlights the body like js", () => {
          const expected = prettyJs(dedent `
            {
              "user" : "kimchy",
              "likes" : 2,
              "message" : "trying out Elasticsearch"
            }
          `);
          expect(pretty).toContain(`0</span><span class="pln">\n</span>${expected}`);
        });
      });
      describe("when the body looks like a bulk request", () => {
        const pretty = prettyConsole(dedent `
          POST /_bulk
          { "index" : { "_index" : "test", "_id" : "1" } }
          { "field1" : "value1" }
          { "delete" : { "_index" : "test", "_id" : "2" } }
        `);
        simpleTests(pretty, "POST", "/_bulk");
        test("highlights the first line like js", () => {
          const expected = prettyJs(`{ "index" : { "_index" : "test", "_id" : "1" } }`);
          expect(pretty.split("\n")[1]).toBe(`</span>${expected}<span class="pln">`);
        });
        test("highlights the second line like js", () => {
          const expected = prettyJs(`{ "field1" : "value1" }`);
          expect(pretty.split("\n")[2]).toBe(`</span>${expected}<span class="pln">`);
        });
        test("highlights the third line like js", () => {
          const expected = prettyJs(`{ "delete" : { "_index" : "test", "_id" : "2" } }`);
          expect(pretty.split("\n")[3]).toBe(`</span>${expected}`);
        });
      });
    });
  });
  describe("for many", () => {
    describe("simple commands", () => {
      const pretty = prettyConsole(dedent `
        POST /_refresh
        POST /twitter/_search?size=0&q=extra:test&filter_path=hits.total
      `);
      describe("the first command", () => {
        simpleTests(pretty, "POST", "/_refresh");
      });
      describe("the second command", () => {
        simpleTests(pretty, "POST", "/twitter/_search", {
          size: 0,
          q: "extra:test",
          filter_path: "hits.total"
        });
      });
    });
    describe("complex commands", () => {
      const pretty = prettyConsole(dedent `
        POST /twitter/_update_by_query
        {
          "slice": {
            "id": 0,
            "max": 2
          },
          "script": {
            "source": "ctx._source['extra'] = 'test'"
          }
        }
        POST /twitter/_update_by_query
        {
          "slice": {
            "id": 1,
            "max": 2
          },
          "script": {
            "source": "ctx._source['extra'] = 'test'"
          }
        }
      `);
      const split = pretty.lastIndexOf("\n", pretty.lastIndexOf("POST"))
      const first = pretty.substring(0, split);
      const second = pretty.substring(split);
      describe("the url", () => {
        simpleTests(first, "POST", "/twitter/_update_by_query");
        test("highlights the first body", () => {
          const expected = prettyJs(dedent `
            {
              "slice": {
                "id": 0,
                "max": 2
              },
              "script": {
                "source": "ctx._source['extra'] = 'test'"
              }
            }
          `);
          expect(first).toContain(expected);
        });
      });
      describe("the second command", () => {
        simpleTests(second, "POST", "/twitter/_update_by_query");
        test("highlights the first body", () => {
          const expected = prettyJs(dedent `
            {
              "slice": {
                "id": 1,
                "max": 2
              },
              "script": {
                "source": "ctx._source['extra'] = 'test'"
              }
            }
          `);
          expect(second).toContain(expected);
        });
      });
    });
  });
});
