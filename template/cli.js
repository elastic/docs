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
const Template = require('./template');
const yargs = require('yargs');

process.on('unhandledRejection', error => {
  console.error(error);
  process.exit(1);
});

const argv = yargs
  .usage('./$0 - follow ye instructions true')
  .option("template", {describe: "Path to the template"}).string("template")
  .option("source", {describe: "Path to the source files"}).string("source")
  .option("dest", {describe: "Path to write the templated files"}).string("dest")
  .option("altsummary", {describe: "Path alternatives summary file if one exists"}).string("dest")
  .option("lang", {describe: "Language of the book"}).string("lang")
  .option("tocmode", {describe: "Are we building a table of contents?"}).boolean("tocmode")
  .demandOption(["template", "source", "dest", "lang"])
  .help()
  .argv;

(async () => {
  const template = await Template(() => fs.createReadStream(argv.template, {
    encoding: 'UTF-8',
    autoDestroy: true,
  }));
  await template.applyToDir(argv.source, argv.dest, argv.lang, argv.altsummary, argv.tocmode);
})();
