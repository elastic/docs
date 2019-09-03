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

import PR from "../../lib/prettify/prettify";

const basic = PR.createSimpleLexer(
  [
    [PR.PR_PUNCTUATION, /^[/?=&]/, null, '/?=&'],
    [PR.PR_PLAIN, /^\s+/, null, ' \t\r\n'],
    [PR.PR_KEYWORD, /^DELETE|HEAD|GET|PATCH|POST|PUT/, null, 'DHGP'],
    ["lang-js", /^(\{.+?\})(?=\s*(DELETE|HEAD|GET|PATCH|POST|PUT|$))/s, null, '{'],
  ],
  [
    [PR.PR_STRING,  /^[^ \s/?=&]+/],
  ]
);

const enhanced = job => {
  basic(job);
  /* Switches the "key" part of a url parameter from a string to a keyword.
   * They arrive as "str" and modify them. */
  for (var i = 0; i < job.decorations.length; i += 2) {
    const start = job.decorations[i];
    const decoration = job.decorations[i + 1];
    if (decoration === "str" && start - 1 > 0) {
      const before = job.sourceCode.charAt(start - 1);
      if (before === "?" || before === "&" ) {
        job.decorations[i + 1] = PR.PR_KEYWORD;
      }
    }
  }
};

PR.registerLangHandler(enhanced, ['console']);
