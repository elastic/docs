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
const { promisify } = require('util');

const readdir = promisify(fs.readdir);
const readFile = promisify(fs.readFile);

describe("air_gapped_template.html", () => {
  let template;
  beforeAll(async () => {
    template = await readFile("air_gapped_template.html", {encoding: "utf8"});
  });
  describe("links", () => {
    /**
     * Outgoing links from the template.
     */
    let links;
    beforeAll(() => {
      links = Array.from(new Set([...template.matchAll(/(?:href|src)="([^"]+)"/g)].map(m => m[1]))).sort();
    });
    /**
     * Resources that we compile or otherwise manipulate on the way into
     * the built-docs repo.
     */
    const compiledWebResources = [
      "/guide/static/styles.css",
      "/guide/static/docs.js",
      "/guide/static/jquery.js"
    ];
    /**
     * Resources that are statically served from the preview app.
     */
    let staticResources;
    beforeAll(async () => {
      staticResources = (await readdir("static")).map(e => `/${e}`);
    });

    it("to expected resources", () => {
      const allResources = ["/guide/", ...compiledWebResources, ...staticResources].sort();
      expect(links).toEqual(allResources);
    });
  });
});
