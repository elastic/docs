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

/*
 * Little server that listens for requests in the form of
 * `${branch}.host/guide/${doc}`, looks up the doc from git and streams
 * it back over the response.
 */

const dedent = require("dedent");
const Git = require("./git");
const http = require("http");
const path = require("path");
const { Readable } = require("stream");
const Template = require("../template/template");
const url = require("url");

const port = 3000;
const git = Git("/docs_build/.repos/target_repo.git");

const requestHandler = async (request, response) => {
  const parsedUrl = url.parse(request.url);
  const branch = gitBranch(request.headers['host']);
  if (parsedUrl.pathname === '/diff') {
    return serveDiff(branch, response);
  }
  if (!parsedUrl.pathname.startsWith('/guide')) {
    response.statusCode = 404;
    response.end();
    return;
  }
  const templateExists = await checkIfTemplateExists(branch);
  /*
   * We're using the existence of the template to check if the branch is
   * "ready" for templating on the fly. There are a few changes that came in
   * with that preparation, like making sure all of the required js is written
   * to the `raw` directory as well.
   */
  const pathPrefix = templateExists ? "raw" : "html";
  const path = pathPrefix + parsedUrl.pathname.substring("/guide".length);
  const requestedObject = `${branch}:${path}`;

  const objectType = await git.objectType(requestedObject);
  switch (objectType) {
    case 'missing':
      response.statusCode = 404;
      response.end(`Can't find ${requestedObject}\n`);
      return;
    case 'tree':
      response.statusCode = 301;
      const sep = requestedObject.endsWith('/') ? '' : '/';
      response.setHeader('Location', `${parsedUrl.pathname}${sep}index.html`);
      response.end();
      return;
    case 'blob':
      return serveBlob(response, branch, templateExists, requestedObject);
    default:
      throw new Error(`Don't know how to return ${objecType}`);
  }
}

const checkIfTemplateExists = async branch => {
  const type = await git.objectType(`${branch}:template.html`);
  switch (type) {
    case 'blob':
      return true;
    case 'missing':
      return false;
    default:
      throw new Error(`The template is a strange object type: ${type}`);
  }
};

const serveDiff = (branch, response) => {
  return new Promise((resolve, reject) => {
    pipeToResponse(
      Readable.from(bufferItr(diffItr(branch), 16 * 1024)),
      response, resolve, reject
    );
  });
};

const pipeToResponse = (out, response, resolve, reject) => {
  response.on("close", resolve);
  response.on("error", reject);
  out.on("error", reject);
  out.pipe(response);
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
}

/**
 * Creates an async iterator describing the diff. The iterator is very "chatty"
 * so is probably best wrapped in bufferItr.
 * @param {string} branch branch to describe
 */
const diffItr = async function* (branch) {
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

const serveBlob = (response, branch, templateExists, requestedObject) => {
  return new Promise((resolve, reject) => {
    let raw = git.catBlob(requestedObject);
    if (templateExists && requestedObject.endsWith(".html")) {
      raw.on("error", reject);
      applyTemplate(branch, requestedObject, raw)
        .then(out => pipeToResponse(out, response, resolve, reject))
        .catch(reject);
    } else {
      pipeToResponse(raw, response, resolve, reject);
    }
  });
};

const applyTemplate = async (branch, requestedObject, out) => {
  const template = Template(() => git.catBlob(`${branch}:template.html`));
  const lang = await loadLang(requestedObject);
  const initialJsState = await loadInitialJsState(requestedObject);
  return template.apply(out[Symbol.asyncIterator](), lang, initialJsState);
};

const loadLang = async requestedObject => {
  const langPath = path.dirname(requestedObject) + "/lang";
  return (await git.catBlobToString(langPath)).trim();
};

const loadInitialJsState = async requestedObject => {
  try {
    const reportPath = path.dirname(requestedObject) + "/alternatives_summary.json";
    const summary = JSON.parse(await git.catBlobToString(reportPath, 10 * 1024));
    return JSON.stringify(Template.buildInitialJsState(summary));
  } catch (err) {
    if (err === "missing") {
      return "{}";
    } else {
      throw err;
    }
  }
};

function gitBranch(host) {
  if (!host) {
    return 'master';
  }
  return host.split('.')[0];
}

const server = http.createServer((request, response) => {
  requestHandler(request, response)
    .catch(err => {
      if (err === "missing") {
        response.statusCode = 404;
        response.end("404!");
      } else {
        console.warn('unhandled error for', request, err);
        /*
         * *try* to set the status code to 500. This might not be possible
         * because we might be in the middle of a chunked transfer. In that
         * case this'll look funny.
         */
        response.statusCode = 500;
        response.end(err.message);
      }
    });
});

server.listen(port, err => {
  if (err) {
    console.error("preview server couldn't listen", err);
    process.exit(1);
  }

  console.info(`preview server is listening on ${port}`);
});

process.on('SIGTERM', () => {
  console.info('preview server shutting down');
  server.close(() => {
    process.exit();
  });
});
