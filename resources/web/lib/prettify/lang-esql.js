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
         [PR['PR_KEYWORD'], /^(?:ABC|AND|ABS|ACOS|ASIN|ATAN|ATAN2|AUTO_BUCKET|AVG|BY|CASE|CEIL|CIDR_MATCH|COALESCE|CONCAT|COS|COSH|COUNT|COUNT_DISTINCT|DATE_EXTRACT|DATE_FORMAT|DATE_PARSE|DATE_TRUNC|DISSECT|DROP|E|ENDS_WITH|ENRICH|EVAL|FLOOR|FROM|GREATEST|GROK|IN|IS|IS_FINITE|IS_INFINITE|IS_NAN|LEFT|LENGTH|LOG10|LTRIM|MAX|MEDIAN|MEDIAN_ABSOLUTE_DEVIATION|MIN|KEEP|LEAST|LIKE|LIMIT|MV_AVG|MV_CONCAT|MV_COUNT|MV_DEDUPE|MV_EXPAND|MV_MAX|MV_MEDIAN|MV_MIN|MV_SUM|NOT|NOW|NULL|OR|PERCENTILE|PI|POW|RENAME|REPLACE|RIGHT|RLIKE|ROUND|ROW|RTRIM|SHOW|SPLIT|SIN|SINH|SORT|SQRT|STARTS_WITH|STATS|SUBSTRING|TAN|TANH|TAU|TO_BOOLEAN|TO_DATETIME|TO_DEGREES|TO_DOUBLE|TO_INTEGER|TO_IP|TO_LONG|TO_RADIANS|TO_STRING|TO_UNSIGNED_LONG|TO_VERSION|TRIM|SUM|WHERE)(?=[^\w-]|$)/i, null],
         [PR['PR_LITERAL'], /^[+-]?(?:\.\d+|\d+(?:\.\d*)?)/i],
         [PR['PR_PLAIN'], /^[a-z_][\w-]*/i],
        ]),
    ['esql']);
