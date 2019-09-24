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

const core = require("./core");
const preview = require("./preview");
const yargs = require("yargs");

process.on('unhandledRejection', error => {
  console.error("unhandled rejection", error);
  process.exit(1);
});

yargs
  .command({
    command: "git <repo>",
    desc: "Serve a repo",
    handler: argv => {
      preview(core.Git(argv.repo));
    },
  })
  .command({
    command: "fs <path>",
    desc: "Serve some files from disk",
    handler: argv => {
      preview(core.Fs(argv.path));
    },
  })
  .version(false)
  .demandCommand()
  .help()
  .argv;
