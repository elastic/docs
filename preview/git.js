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

const child_process = require("child_process");
const { Transform } = require("stream");

/**
 * Git operations used by the preview. We'd love to use NodeGit but it doesn't
 * looks like it is asynchronous and/or streaming in the places where we need
 * it to be.
 */
module.exports = dir => {return {
  /**
   * Returns a promise that will contain the type of the object. Will be one of
   * `blob`, `commit`, `tag`, `tree`, or `missing`. The first four are defined
   * [here]{@link http://shafiul.github.io/gitbook/1_the_git_object_model.html}.
   * `missing` is for missing objects.
   */
  objectType: object => {
    return new Promise((resolve, reject) => {
      const opts = {
        cwd: dir,
        max_buffer: 64,
      };
      child_process.execFile(
        "git", ["cat-file", "-t", object], opts, toStringHandler(resolve, reject, resolve)
      );
    });
  },
  /**
   * Returns a promise containing the contents of an object.
   * @param {int} sizeLimit maximum size of the buffer for the object
   */
  catBlobToString: (object, sizeLimit) => {
    return new Promise((resolve, reject) => {
      const opts = {
        cwd: dir,
        max_buffer: sizeLimit,
      };
      child_process.execFile(
        "git", ["cat-file", "blob", object], opts, toStringHandler(resolve, reject, reject)
      );
    });
  },
  /**
   * Returns a stream containing the contents of the object.
   */
  catBlob: object => {
    return streamChild(child_process.spawn(
      "git", ["cat-file", "blob", object], {cwd: dir}
    ));
  },
  diffLastCommit: branch => {
    const stream = streamChild(child_process.spawn(
      "git",
      ["diff-tree", "-z", "--find-renames", "--numstat", branch, "--"],
      {
        cwd: dir,
        /*
         * We use the magic 'buffer' encoding so we don't have to build a
         * a string out of the whole thing at once. We have convenient nuls
         * in the parsing process that we can use to "chunk" this.
         */
        encoding: 'buffer',
      }
    ));
    return parseDiffTreeZ(stream[Symbol.asyncIterator]());
  },
  /**
   * Turn a spawned child process into a stream containing its stdout and
   * emitting an error if it fails. Exported for testing only.
   */
  _streamChild: streamChild,
  /**
   * Parse the output of `git diff-tree -z --find-renames --numstat` as an
   * async generator. Exported for testing only.
   */
  _parseDiffTreeZ: parseDiffTreeZ,
}};

const streamChild = (child) => {
  // Error should be fairly short so we can safely spool them into a variable.
  let stderrBuffer = '';
  child.stderr.setEncoding('utf8');
  child.stderr.addListener('data', chunk => {
    stderrBuffer += chunk;
  });

  let closed = false;
  let flushCallback;
  let childCloseState;
  const flushIfReady = () => {
    if (!flushCallback || !childCloseState) {
      // Not ready.
      return;
    }
    /*
     * We can get this call multiple times for some reason. Lets just ignore
     * the second one.....
     */
    if (closed) {
      return;
    }
    closed = true;
    /*
     * Since we've closed stdout we can be sure that our transform stream has
     * received its `flush` callback. So we delegate to that now to close
     * the transform stream with the results of the subprocess.
     */
    if (childCloseState.code) {
      /*
       * Normalize some "not found" style errors from git so the caller can
       * 404 on them.
       */
      let missing = stderrBuffer.includes("Not a valid object name");
      missing |= stderrBuffer.includes("fatal: bad revision");
      if (missing) {
        flushCallback("missing");
      } else {
        flushCallback(failureMessage(`Child failed with code ${childCloseState.code}`, stderrBuffer));
      }
    } else if (childCloseState.signal) {
      flushCallback(failureMessage(`Child died with signal ${childCloseState.signal}`, stderrBuffer));
    } else {
      flushCallback();
    }
  };

  const out = child.stdout.pipe(new Transform({
    transform(chunk, _encoding, callback) {
      callback(null, chunk);
    },
    flush(callback) {
      // Wait to emit the end until the process closes.
      flushCallback = callback;
      flushIfReady();
    }
  }));

  child.addListener('close', (code, signal) => {
    childCloseState = {code: code, signal: signal};
    flushIfReady();
  });

  return out;
}

const failureMessage = (firstPart, stderr) => {
  if (stderr) {
    return `${firstPart} and stderr:\n${stderr}`;
  }
  return firstPart;
}

const parseDiffTreeZ = async function* (itr) {
  const loadFirstChunk = await itr.next();
  if (loadFirstChunk.done) {
    // Empty diff!
    return;
  }
  let chunk = loadFirstChunk.value;
  const sliceOffNul = async from => {
    while (true) {
      const nextNul = chunk.indexOf("\0", from);
      if (nextNul === -1) {
        const load = await itr.next();
        if (load.done) {
          if (chunk.length === 0) {
            return null;
          }
          // The iterator is done here so we don't call itr.throw.
          throw new Error(`Trailing garbage after diff: ${chunk}`);
        } else {
          /*
           * Concat *is* a copying operations which is important because this
           * is the operation that releases the memory from the last chunk.
           */
          chunk = Buffer.concat([chunk, load.value]);
        }
      } else {
        const result = chunk.toString('utf8', from, nextNul);
        /*
         * Slice off the chunk working part that we're returning. Buffer
         * slicing in nodejs is a non-copying operation so this is quick.
         */
        chunk = chunk.slice(nextNul + 1);
        return result;
      }
    }
  };
  /*
   * Parses output from `git diff-tree -z` which is in
   * one of two formats:
   * * added lines<tab>removed lines<tab>path<nul>
   * * added lines<tab>removed lines<nul>source path<nul>destination path<nul>
   * The second one is only used when git detects a rename.
   */
  while (true) {
    let work = await sliceOffNul();
    if (work === null) {
      // Done!
      return;
    }
    if (work[work.length - 1] === '\t') {
      work = work.slice(work, -1);
    }
    const parts = work.split('\t');
    if (parts.length === 3) {
      const [added, removed, path] = parts;
      yield {
        path: path,
        added: added,
        removed: removed,
      };
    } else if (parts.length === 2) {
      const [added, removed] = parts;
      const path = await sliceOffNul();
      const movedToPath = await sliceOffNul();
      yield {
        path: path,
        movedToPath: movedToPath,
        added: added,
        removed: removed,
      };
    } else if (parts.length === 1) {
      // The commit hash. Ignore it.
    } else {
      // Prematurely end the iterator because we've encountered a parsing error.
      itr.throw(new Error(`Strange entry fom git: ${work}`));
    }
  }
}

const toStringHandler = (resolve, reject, onMissing) => (err, stdout) => {
  if (err) {
    if (err.message.includes("Not a valid object name")) {
      onMissing("missing");
    } else {
      reject(err);
    }
  } else {
    resolve(stdout.trim());
  }
};
