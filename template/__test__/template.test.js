/**
 * @license
 * Licensed to Elasticsearch under one or more contributor
 * license agreements. See the NOTICE file distributed with
 * this work for additional information regarding copyright
 * ownership. Elasticsearch licenses this file to you under
 * the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

'use strict';

const fs = require('fs');
const Template = require('../template');

describe(Template, () => {
  describe("buildInitialJsState", () => {
    describe("for empty alternatives summary", () => {
      const state = Template.buildInitialJsState({});
      test("not to have any alternatives", () => {
        expect(state).toStrictEqual({
          alternatives: {}
        });
      });
    });
    describe("for a small alternatives summary", () => {
      const state = Template.buildInitialJsState({
        console: {
          total: 2,
          alternatives: {
            csharp: { found: 1 },
            js: { found: 2 },
            python: { found: 0 }
          }
        }
      });
      test("shows languages without any alternatives as not having any", () =>{
        expect(state).toMatchObject({
          alternatives: {
            console: {
              python: {hasAny: false}
            }
          }
        });
      });
      test("shows languages with any alteratives as having any", () =>{
        expect(state).toMatchObject({
          alternatives: {
            console: {
              csharp: {hasAny: true},
              js: {hasAny: true},
            }
          }
        });
      });
    });
  });
  describe("apply", () => {
    let template = Template(() =>
      fs.createReadStream("../resources/web/template.html", {
        encoding: 'UTF-8',
        autoDestroy: true,
      })
    );
    template.applyToString = async (raw, lang, initialJsState) => {
      const rawItr = (function* () {
        yield raw;
      })();
      return template.applyToItr(rawItr, lang, initialJsState);
    };
    template.applyToItr = async (rawItr, lang, initialJsState) => {
      let result = '';
      for await (const chunk of template.apply(rawItr, lang, initialJsState)) {
        result += chunk;
      }
      return result;
    };
    describe("when applied to simple html", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToString(`
          <!DOCTYPE html>
          <html>
            <head><title>foo</title></head>
            <body>words words words</body>
          </html>`, 'en', '{initial:{js:"state"}}');
      });
      test("outputs the html5 doctype", () => {
        expect(result).toMatch(/^<!DOCTYPE html>/);
      });
      test("outputs the language", () => {
        expect(result).toContain('<section id="guide" lang="en">');
      });
      test("outputs body between recognizable tags", () => {
        expect(result).toMatch(
          /<!-- start body -->\s+words words words\s+<!-- end body -->/
        );
      });
      test("outputs initial js at the bottom of the body", () => {
        expect(result).toMatch(
          /<script type="text\/javascript">\s+window.initial_state = {initial:{js:"state"}}<\/script>\s+<\/body>/
        );
      });
    });
    describe("when the head and body are empty", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToString(`
          <!DOCTYPE html>
          <html>
            <head></head>
            <body></body>
          </html>`);
      });
      test("doesn't add anything to the head", () => {
        expect(result).toMatch(
          /<head>\s+<meta http-equiv="content-type"/
        );
      });
      test("outputs an empty body", () => {
        expect(result).toMatch(
          /<!-- start body -->\s+<!-- end body -->/
        );
      });
    });
    describe("when it gets an empty document", () => {
      test("throws an exception", async () => {
        return expect(template.applyToItr((function* () {
          // Intentionally doesn't yield
        })())).rejects.toThrow(/raw didn't have any data/);
      });
    });
    describe("when it gets a document without a head", () => {
      test("throws an exception", async () => {
        return expect(template.applyToString(`<html><body>words</body></html>`))
          .rejects.toThrow(/Couldn't find <head> in raw/);
      });
    });
    describe("when it gets a document with an unclosed head", () => {
      test("throws an exception", async () => {
        return expect(template.applyToString(`<html><head><body>words</body></html>`))
          .rejects.toThrow(/Couldn't find <\/head> in raw/);
      });
    });
    describe("when it gets a document without a body", () => {
      test("throws an exception", () => {
        return expect(template.applyToString(`<html><head><script>foo</script></head></html>`))
          .rejects.toThrow(/Couldn't find <body in raw/);
      });
    });
    describe("when it gets a document with an unclosed body", () => {
      test("throws an exception", () => {
        return expect(template.applyToString(`<html><head><script>foo</script></head><body></html>`))
          .rejects.toThrow(/Couldn't find <\/body> in raw/);
      });
    });
    describe("when the head start tag is in two chunks", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToItr((function* () {
          yield '<html><he';
          yield 'ad>head stuff</head><body></body></html>';
        })());
      });
      test("outputs the correct head anyway", () => {
        expect(result).toMatch(/<head>\s+head stuff/);
      });
    });
    describe("when the head end tag is in two chunks", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToItr((function* () {
          yield '<html><head>head stuff</he';
          yield 'ad><body></body></html>';
        })());
      });
      test("outputs the correct head anyway", () => {
        expect(result).toMatch(/<head>\s+head stuff/);
      });
    });
    describe("when the body start tag is in two chunks", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToItr((function* () {
          yield '<html><head></head><b';
          yield 'ody>body stuff</body></html>';
        })());
      });
      test("outputs the correct body anyway", () => {
        expect(result).toMatch(
          /<!-- start body -->\s+body stuff\s+<!-- end body -->/
        );
      });
    });
    describe("when the body end tag is in two chunks", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToItr((function* () {
          yield '<html><head></head><body>body stuff</';
          yield 'body></html>';
        })());
      });
      test("outputs the correct body anyway", () => {
        expect(result).toMatch(
          /<!-- start body -->\s+body stuff\s+<!-- end body -->/
        );
      });
    });
    describe("when the input is in as many chunks as possible", () => {
      let result;
      beforeAll(async () => {
        result = await template.applyToItr((function* () {
          for (const c of [...'<html><head>head stuff</head><body>body stuff</body></html>']) {
            yield c;
          }
        })());
      });
      test("outputs the correct head anyway", () => {
        expect(result).toMatch(/<head>\s+head stuff/);
      });
      test("outputs the correct body anyway", () => {
        expect(result).toMatch(
          /<!-- start body -->\s+body stuff\s+<!-- end body -->/
        );
      });
    });
  });
});
