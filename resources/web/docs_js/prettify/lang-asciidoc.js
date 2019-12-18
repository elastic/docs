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

PR.registerLangHandler(PR.createSimpleLexer(
  [
  ],
  [
    [PR.PR_COMMENT, /\/\/[^\n]*(\n|$)/],
    [PR.PR_TAG, /\[\[/],
    ["lang-asciidoc-block-attribute-list", /\[([^\]]+)\]/],
    [PR.PR_TAG, /=/],
    [PR.PR_TAG, /\+\+\+\+/],
    [PR.PR_TAG, /\./],
    [PR.PR_TAG, /--/],
    [PR.PR_TAG, /\[|\]/],
  ]
), ["asciidoc"]);

const basicAttributeList = PR.createSimpleLexer(
  [
  ],
  [
    [PR.PR_STRING, /[^=,]+/],
    [PR.PR_PUNCTUATION, /[,=]/],
  ]
);
const enhancedAttributeList = job => {
  basicAttributeList(job);
  /* Switches the "key" part of parameter lists to keywords. */
  for (var i = 0; i < job.decorations.length; i += 2) {
    const decoration = job.decorations[i + 1];
    if (decoration === "str") {
      const next = job.decorations[i + 2];
      if (job.sourceCode.charAt(next - 1) === "=") {
        job.decorations[i + 1] = PR.PR_KEYWORD;
      }
    }
  }
};
PR.registerLangHandler(enhancedAttributeList, ["asciidoc-block-attribute-list"]);
