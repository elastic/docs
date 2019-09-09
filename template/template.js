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
const path = require('path');
const {promisify} = require('util');
const recursiveCopy = promisify(require('recursive-copy'));

const mkdir = promisify(fs.mkdir);
const readdir = promisify(fs.readdir);
const readFile = promisify(fs.readFile);
const stat = promisify(fs.stat);
const writeFile = promisify(fs.writeFile);

module.exports = async templatePath => {
  const contents = await readFile(templatePath, {encoding: 'UTF-8'});

  const map = {};
  const parts = contents.split(/<!-- (DOCS \w+) -->/).map((part, index) => {
    const matcher = /DOCS (\w+)/.exec(part);
    if (matcher) {
      map[matcher[1]] = index;
      return '';
    }
    return part;
  });
  const apply = (raw, lang, initialJsState) => {
    const head = /<head>(.+?)<\/head>/s.exec(raw);
    if (!head) {
      throw new Error(`Couldn't find head in ${raw}`);
    }
    const body = /<body>(.+?)<\/body>/s.exec(raw);
    if (!body) {
      throw new Error(`Couldn't find body in ${raw}`);
    }

    const theseParts = parts.slice(0);
    theseParts[map.PREHEAD] = head[1];
    theseParts[map.LANG] = `lang="${lang}"`;
    theseParts[map.BODY] = body[1];
    theseParts[map.FINAL] = `
<script type="text/javascript">
window.initial_state = ${initialJsState}</script>`;
    return theseParts.join('');
  };
  const buildInitialJsStateFromFile = async alternativesSummary => {
    if (!alternativesSummary) {
      return "{}";
    }
    const readAltSummary = JSON.parse(await readFile(alternativesSummary));
    return JSON.stringify(module.exports.buildInitialJsState(readAltSummary));
  };
  const applyToDir = async (sourcePath, destPath, lang, alternativesSummary, tocMode) => {
    const initialJsState = await buildInitialJsStateFromFile(alternativesSummary);
    const entries = await readdir(sourcePath);
    await mkdir(destPath, {recursive: true});
    for (var e = 0; e < entries.length; e++) {
      const basename = entries[e];
      const source = path.join(sourcePath, basename);
      const dest = path.join(destPath, basename);

      if (source === alternativesSummary) {
        continue;
      }

      const sourceStat = await stat(source);
      if (sourceStat.isDirectory()) {
        /*
         * Usually books are built to empty directories and any
         * subdirectories contain images or snippets and should be copied
         * wholesale into the templated directory. But the book's
         * multi-version table of contents is different because it is built
         * to the root directory of all book versions so subdirectories are
         * other books! Copying them would overwrite the templates book
         * files with untemplated book files. That'd be bad!
         */
        if (!tocMode) {
          await recursiveCopy(source, dest);
        }
        continue;
      }
      if (!basename.endsWith(".html")) {
        await recursiveCopy(source, dest);
        continue;
      }
      const contents = await readFile(source, {encoding: 'UTF-8'});
      const result = apply(contents, lang, initialJsState);
      await writeFile(dest, result, {encoding: 'UTF-8'});
    };
  };
  return {
    apply: apply,
    applyToDir: applyToDir,
  };
};
module.exports.buildInitialJsState = alternativesSummary => {
  const result = {};
  result.alternatives = {};
  for (var sourceLang in alternativesSummary) {
    const forSourceLang = alternativesSummary[sourceLang];
    result.alternatives[sourceLang] = {};
    for (var altLang in forSourceLang.alternatives) {
      result.alternatives[sourceLang][altLang] = {
        hasAny: forSourceLang.alternatives[altLang].found > 0,
      };
    }
  }
  return result;
};
