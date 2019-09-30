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
const {Readable} = require('stream');
const {promisify} = require('util');
const recursiveCopy = promisify(require('recursive-copy'));

const mkdir = promisify(fs.mkdir);
const readdir = promisify(fs.readdir);
const readFile = promisify(fs.readFile);
const stat = promisify(fs.stat);

module.exports = templateSource => {
  const apply = (rawItr, lang, initialJsState) => {
    /*
     * We apply the template by walking a stream for the template and a stream
     * for the raw page in parallel. We do this instead of pulling everything
     * into memory and manipulating it to keep the memory usage small even when
     * the template or raw page are very large. We expect the most memory this
     * can use is 3x the sum of the sum of highWaterMark of both streams.
     */
    const Gatherer = async (name, itr) => {
      let chunk = '';
      const nextChunk = async preserve => {
        const result = await itr.next();
        if (result.done) {
          return false;
        }
        if (preserve) {
          /* If we're looking for a marker then we need to keep some characters
           * at the end of the chunk in case the marker is on the edge. */
          const slice = Math.max(0, chunk.length - preserve);
          chunk = chunk.slice(slice) + result.value;
          // TODO check if slice + keeps a copy of internal memory. This implementation assumes it *doesn't*
        } else {
          chunk = result.value;
        }
        return true;
      };
      if (!await nextChunk()) {
        throw new Error(`${name} didn't have any data`)
      }
      const gather = async function* (marker) {
        let index;
        while ((index = chunk.indexOf(marker)) < 0) {
          const slice = chunk.length - marker.length;
          if (slice > 0) {
            yield chunk.slice(0, slice);
          }
          if (!await nextChunk(marker.length)) {
            throw new Error(`Couldn't find ${marker} in ${name}:\n${chunk}`);
          }
        }
        yield chunk.slice(0, index);
        chunk = chunk.slice(index + marker.length);
      };
      const dump = async marker => {
        let index;
        while ((index = chunk.indexOf(marker)) < 0) {
          if (!await nextChunk(marker.length)) {
            throw new Error(`Couldn't find ${marker} in ${name}:\n${chunk}`);
          }
        }
        chunk = chunk.slice(index + marker.length);
      }
      async function* remaining() {
        yield chunk;
        while (await nextChunk()) {
          yield chunk;
        }
      }
      return {
        gather: gather,
        dump: dump,
        remaining: remaining,
      };
    };

    async function* asyncApply() {
      const templateStream = templateSource();
      try {
        const template = await Gatherer('template', templateStream[Symbol.asyncIterator]());
        yield* template.gather("<!-- DOCS PREHEAD -->");
        const raw = await Gatherer('raw', rawItr);
        await raw.dump("<head>");
        yield* raw.gather("</head>");
        yield* template.gather("<!-- DOCS LANG -->");
        yield `lang="${lang}"`;
        yield* template.gather("<!-- DOCS BODY -->");
        await raw.dump("<body>");
        yield* raw.gather("</body>");
        yield* template.gather("<!-- DOCS FINAL -->");
        yield `<script type="text/javascript">
  window.initial_state = ${initialJsState}</script>`;
        yield* template.remaining();
      } catch (err) {
        templateStream.destroy(err);
        throw err;
      }
    }

    // TODO this defaults to object mode and maybe shouldn't.
    return Readable.from(asyncApply());
  };
  const buildInitialJsStateFromFile = async alternativesSummaryFile => {
    let alternativesSummary;
    try {
      alternativesSummary = await readFile(alternativesSummaryFile, {
        encoding: "utf8",
      });
    } catch (err) {
      if (err.errno === -2) { // ENOENT
        return "{}";
      }
      throw err;
    }
    return JSON.stringify(module.exports.buildInitialJsState(JSON.parse(alternativesSummary)));
  };
  const applyToDir = async (sourcePath, destPath, tocMode) => {
    const langFile = `${sourcePath}/lang`;
    const alternativesSummaryFile = `${sourcePath}/alternatives_summary.json`;
    const alternativesReportFile = `${sourcePath}/alternatives_report.json`;
    const tocFile = `${sourcePath}/toc.html`;
    const initialJsState = await buildInitialJsStateFromFile(alternativesSummaryFile);
    const lang = (await readFile(langFile, {
      encoding: "utf8",
    })).trim();
    const entries = await readdir(sourcePath);
    await mkdir(destPath, {recursive: true});
    for (var e = 0; e < entries.length; e++) {
      const basename = entries[e];
      const source = path.join(sourcePath, basename);
      const dest = path.join(destPath, basename);

      if (source === langFile) {
        continue;
      }
      if (source === alternativesSummaryFile) {
        continue;
      }
      if (source === alternativesReportFile) {
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
      if (source === tocFile || !basename.endsWith(".html")) {
        await recursiveCopy(source, dest);
        continue;
      }
      const raw = fs.createReadStream(source, {encoding: 'UTF-8'});
      const write = fs.createWriteStream(dest, {encoding: 'UTF-8'});
      await new Promise((resolve, reject) => {
        const out = apply(raw[Symbol.asyncIterator](), lang, initialJsState);
        write.on("close", resolve);
        write.on("error", reject);
        out.on("error", write.destroy);
        out.pipe(write);
      }).finally(() => raw.close());
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
