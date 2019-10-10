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

const bufferItr = require("../buffer_itr.js");

const bufferedCollect = async itrGen => {
  const all = [];
  for await (const c of bufferItr(itrGen(), 20)) {
    all.push(c);
  }
  return all;
}

describe(bufferItr, () => {
  describe("when there aren't any entries",  () => {
    it("emits no entries", async () => {
      expect(await bufferedCollect(function* () {
      })).toStrictEqual([]);
    });
  });
  describe("when there is a single string", () => {
    it("emits a single result", async () => {
      expect(await bufferedCollect(function* () {
        yield "foo";
      })).toStrictEqual(["foo"]);
    });
  });
  describe("when there are a few longs strings", () => {
    it("emits each one", async () => {
      expect(await bufferedCollect(function* () {
        yield "string that is more than twenty characters. ";
        yield "another string";
      })).toStrictEqual([
        "string that is more than twenty characters. ",
        "another string"
      ]);
    });
  });
  describe("when there are a few short strings", () => {
    it("they are all bundled", async () => {
      expect(await bufferedCollect(function* () {
        yield "a";
        yield "b";
        yield "c";
        yield "d";
      })).toStrictEqual(["abcd"]);
    });
  });
});
