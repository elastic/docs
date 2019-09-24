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

const http = require("http");
const path = require("path");
const url = require("url");
const Template = require("../template/template");

const port = 3000;

const requestHandler = async (core, parsedUrl, response) => {
  if (parsedUrl.pathname === '/diff') {
    return new Promise((resolve, reject) => {
      pipeToResponse(core.diff(), response, resolve, reject);
    });
  }
  if (!parsedUrl.pathname.startsWith('/guide')) {
    response.statusCode = 404;
    response.end();
    return;
  }

  const path = parsedUrl.pathname.substring("/guide".length);
  const type = contentType(path);
  const file = await core.file(path, type);
  if (file === "dir") {
    response.statusCode = 301;
    const sep = parsedUrl.pathname.endsWith('/') ? '' : '/';
    response.setHeader('Location', `${parsedUrl.pathname}${sep}index.html`);
    response.end();
    return;
  }
  if (file === "missing") {
    response.statusCode = 404;
    response.end(`Can't find ${parsedUrl.pathname}\n`);
    return;
  }

  response.setHeader('Content-Type', type);
  if (file.hasTemplate && type === "text/html; charset=utf-8") {
    const template = Template(file.template);
    console.log("asdfadsf1");
    const lang = await file.lang();
    console.log("asdfadsf2");
    const initialJsState = await buildInitialJsState(file.alternativesReport);
    console.log("asdfadsf3");
    const templated = template.apply(
      file.stream[Symbol.asyncIterator](), lang.trim(), initialJsState
    );
    return new Promise((resolve, reject) => {
      file.stream.on("error", reject);
      pipeToResponse(templated, response, resolve, reject);
    });
  } else {
    return new Promise((resolve, reject) => {
      pipeToResponse(file.stream, response, resolve, reject);
    });
  }
}

const pipeToResponse = (out, response, resolve, reject) => {
  response.on("close", resolve);
  response.on("error", reject);
  out.on("error", reject);
  out.pipe(response);
}

const contentType = rawPath => {
  const ext = path.extname(rawPath);
  switch (ext) {
    case ".css":
      return "text/css";
    case ".gif":
      return "image/gif";
    case ".html":
    case ".htm":
      return "text/html; charset=utf-8";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".js":
      return "application/javascript";
    case ".svg":
      return "image/svg+xml";
    default:
      return "text/plain";
  }
};

const buildInitialJsState = async alternativesReportSource => {
  try {
    console.log("checking alternatives");
    const parsed = JSON.parse(await alternativesReportSource());
    console.log("building initial js");
    return JSON.stringify(Template.buildInitialJsState(parsed));
  } catch (err) {
    if (err === "missing") {
      return "{}";
    }
    throw err;
  }
};

const hostPrefix = host => {
  if (!host) {
    return null;
  }
  const dot = host.indexOf(".");
  if (dot === -1) {
    return null;
  }
  return host.substring(0, dot);
};

module.exports = Core => {
  const server = http.createServer((request, response) => {
    const parsedUrl = url.parse(request.url);
    const prefix = hostPrefix(request.headers['host']);
    const core = Core(prefix);
    requestHandler(core, parsedUrl, response)
      .catch(err => {
        if (err === "missing") {
          response.statusCode = 404;
          response.end("404!");
        } else {
          console.warn('unhandled error for', prefix, parsedUrl, err);
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
};
