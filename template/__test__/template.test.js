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

const template = require('../template');

describe(template, () => {
  describe("buildInitialJsState", () => {
    describe("for empty alternatives summary", () => {
      const state = template.buildInitialJsState({});
      test("not to have any alternatives", () => {
        expect(state).toStrictEqual({
          alternatives: {}
        });
      });
    });
    describe("for a small alternatives summary", () => {
      const state = template.buildInitialJsState({
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
    let t;
    beforeAll(async () => {
      t = await template("../resources/web/template.html");
    });
    describe("when applied to simple html", () => {
      let result;
      beforeAll(() => {
        result = t.apply(`
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
  });
});
