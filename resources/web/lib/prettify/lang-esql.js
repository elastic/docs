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
         [PR['PR_KEYWORD'], /^(?:ABS|ACOS|AND|APPEND_SEPARATOR|AS|ASC|ASIN|ATAN|ATAN2|AUTO_BUCKET|AVG|BY|CASE|CEIL|CIDR_MATCH|COALESCE|CONCAT|COS|COSH|COUNT|COUNT_DISTINCT|DATE_DIFF|DATE_EXTRACT|DATE_FORMAT|DATE_PARSE|DATE_TRUNC|DESC|DISSECT|DROP|E|ENDS_WITH|ENRICH|EVAL|FIRST|FLOOR|FROM|GREATEST|GROK|IN|IS|IS_FINITE|IS_INFINITE|IS_NAN|IS NOT NULL|IS NULL|LEFT|LENGTH|LOG|LOG10|LTRIM|MAX|MEDIAN|MEDIAN_ABSOLUTE_DEVIATION|MIN|KEEP|LAST|LEAST|LIKE|LIMIT|METADATA|MV_AVG|MV_CONCAT|MV_COUNT|MV_DEDUPE|MV_EXPAND|MV_FIRST|MV_LAST|MV_MAX|MV_MEDIAN|MV_MIN|MV_SUM|NOT|NOW|NULL|NULLS|ON|OR|PERCENTILE|PI|POW|RENAME|REPLACE|RIGHT|RLIKE|ROUND|ROW|RTRIM|SHOW|SPLIT|SIN|SINH|SORT|SQRT|ST_CENTROID|STARTS_WITH|STATS|SUBSTRING|SUM|TAN|TANH|TAU|TO_BOOL|TO_BOOLEAN|TO_CARTESIANPOINT|TO_CARTESIANSHAPE|TO_DATETIME|TO_DBL|TO_DEGREES|TO_DOUBLE|TO_DT|TO_GEOPOINT|TO_GEOSHAPE|TO_INT|TO_INTEGER|TO_IP|TO_LONG|TO_LOWER|TO_RADIANS|TO_STR|TO_STRING|TO_UL|TO_ULONG|TO_UNSIGNED_LONG|TO_UPPER|TO_VER|TO_VERSION|TRIM|WHERE|WITH)(?=[^\w-]|$)/i, null],
         [PR['PR_LITERAL'], /^[+-]?(?:\.\d+|\d+(?:\.\d*)?)/i],
         [PR['PR_PLAIN'], /^[a-z_][\w-]*/i],
        ]),
    ['esql']);
