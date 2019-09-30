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

const fs = require("fs");
const dedent = require("dedent");
const Git = require("./git");
const path = require("path");
const { Readable } = require("stream");
const { promisify } = require('util');

const stat = promisify(fs.stat);
const readFile = promisify(fs.readFile);

const GitCore = (defaultTemplate, repoPath) => {
  const hostInfo = hostPrefix => {
    if (!hostPrefix) {
      return [defaultTemplate, "master"];
    }
    let prefix = hostPrefix;
    let template;
    if (prefix.startsWith("gapped_")) {
      template = "air_gapped_template.html";
      prefix = prefix.substring("gapped_".length);
    } else {
      template = "template.html";
    }
    return [template, prefix];
  };

  const git = Git(repoPath);
  return hostPrefix => {
    const [templateName, branch] = hostInfo(hostPrefix);

    return {
      diff: () => Readable.from(bufferItr(diffItr(git, branch), 16 * 1024)),
      file: async requestedPath => {
        const templateExists = await hasTemplate(git, branch);
        /*
         * We're using the existence of the template to check if the branch is
         * "ready" for templating on the fly. There are a few changes that came in
         * with that preparation, like making sure all of the required js is written
         * to the `raw` directory as well.
         */
        const pathPrefix = templateExists ? "raw" : "html";
        const requestedObject = `${branch}:${pathPrefix}${requestedPath}`;
        const objectType = await git.objectType(requestedObject);
        switch (objectType) {
          case "missing":
            return "missing";
          case "tree":
            return "dir";
          case 'blob':
            const dir = path.dirname(requestedObject);
            return {
              hasTemplate: templateExists,
              stream: git.catBlob(requestedObject),
              template: () => git.catBlob(`${branch}:${templateName}`),
              lang: () => git.catBlobToString(`${dir}/lang`),
              alternativesReport: () => git.catBlobToString(
                `${dir}/alternatives_summary.json`, 10 * 1024
              ),
            };
          default:
            throw new Error(`Don't know how to return ${objecType}`);
        }
      },
    };
  };
};

const FsCore = (defaultTemplate, rootPath) => {
  const hostInfo = hostPrefix => {
    if (!hostPrefix) {
      return defaultTemplate;
    }
    return "gapped" === hostPrefix ? "air_gapped_template.html" : "template.html";
  };
  return hostPrefix => {
    const template = hostInfo(hostPrefix);
    const readAlternativesReport = async dir => {
      try {
        return await readFile(`${dir}alternatives_summary.json`, { encoding: "utf8" });
      } catch (err) {
        if (err.code === "ENOENT") {
          throw "missing";
        }
        throw err;
      }
    };
    return {
      diff: () => {
        const r = new Readable;
        r.push("diff not supported");
        r.push(null);
        return r;
      },
      file: async requestedPath => {
        const realPath = `${rootPath}/${requestedPath}`;
        let pathStat;
        try {
          pathStat = await stat(realPath);
        } catch (err) {
          if (err.code === "ENOENT") {
            return "missing";
          }
          throw err;
        }
        if (pathStat.isDirectory()) {
          return "dir";
        }
        const dir = path.dirname(realPath);
        return {
          hasTemplate: true,
          stream: fs.createReadStream(realPath),
          template: () => fs.createReadStream(`/docs_build/resources/web/${template}`),
          lang: () => readFile(`${dir}lang`, { encoding: "utf8" }),
          alternativesReport: () => readAlternativesReport(dir),
        };
      }
    };
  };
};

module.exports = {
  Git: GitCore,
  Fs: FsCore,
};

const hasTemplate = async (git, branch) => {
  const type = await git.objectType(`${branch}:template.html`);
  switch (type) {
    case 'blob':
      return true;
    case 'missing':
      return false;
    default:
      throw new Error(`The template is a strange object type: ${type}`);
  }
}

/**
 * Buffers an async iterator until its output is at least min characters
 * @param {Generator} itr async iterator that returns a string to buffer 
 */
const bufferItr = async function* (itr, min) {
  let buffer = '';
  for await (const chunk of itr) {
    buffer += chunk;
    if (buffer.length > min) {
      yield buffer;
    }
  }
  yield buffer;
};

/**
 * Creates an async iterator describing the diff. The iterator is very "chatty"
 * so is probably best wrapped in bufferItr.
 * @param {string} branch branch to describe
 */
const diffItr = async function* (git, branch) {
  yield dedent `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Diff for ${branch}</title>
    </head>
    <body><ul>\n`;

  let sawAny = false;
  for await (const change of git.diffLastCommit(branch)) {
    // Skip boring files
    if (!change.path.startsWith("raw/")) {
      continue;
    }
    // Strip the prefixes from the paths
    change.path = change.path.substring("raw/".length);
    if (change.movedToPath) {
      change.movedToPath = change.movedToPath.substring("raw/".length);
    }

    // Build the output html
    yield `  <li>+${change.added} -${change.removed}`;
    const linkTarget = change.movedToPath ? change.movedToPath : change.path;
    yield ` <a href="/guide/${linkTarget}">`;
    yield change.movedToPath ? `${change.path} -> ${change.movedToPath}` : change.path;
    yield `</a>\n`;
    sawAny = true;
  }
  yield `</ul>`;
  if (!sawAny) {
    yield `<p>There aren't any differences!</p>`;
  }
  yield `</html>\n`;
};
