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

import PR from "./prettify";

PR['registerLangHandler'](
    PR['createSimpleLexer'](
        [
         [PR['PR_PLAIN'],       /^[\t\n\r \xA0]+/, null, '\t\n\r \xA0'],
         [PR['PR_STRING'],      /^(?:"(?:[^\"\\]|\\.)*")/, null, '"']
        ],
        [
         [PR['PR_COMMENT'], /^(?:\/\/[^\r\n]*|\/\*[\s\S]*?(?:\*\/|$))/],
         [PR['PR_KEYWORD'], /^(?:AND|OR|BY|DISSECT|DROP|EVAL|FROM|GROK|LIKE|LIMIT|MV_EXPAND|NOT|PROJECT|RENAME|RLIKE|ROW|SHOW|SORT|STATS|WHERE)(?=[^\w-]|$)/i, null],
         [PR['PR_LITERAL'], /^[+-]?(?:\.\d+|\d+(?:\.\d*)?)/i],
         [PR['PR_PLAIN'], /^[a-z_][\w-]*/i],
        ]),
    ['esql']);
