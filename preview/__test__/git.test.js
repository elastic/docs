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

const {promisify} = require("util");

const fs = require("fs");
const child_process = require("child_process");
const Git = require("../git");
const rmfr = require("rmfr");
const { Readable } = require("stream");

const execFile = promisify(child_process.execFile);
const mkdir = promisify(fs.mkdir);
const unlink = promisify(fs.unlink);
const writeFile = promisify(fs.writeFile);

const collect = async stream => {
  let all = '';
  for await (const c of stream) {
    all += c;
  }
  return all;
}

describe("git", () => {
  const git = Git("/docs_build");

  describe("objectType", () =>{
    describe("when pointed at a blob", () => {
      test("resolves to `blob`", () => {
        return expect(git.objectType("HEAD:preview/git.js"))
          .resolves.toBe("blob");
      });
    });
    describe("when pointed at a commit", () => {
      test("resolves to `commit`", () => {
        return expect(git.objectType("HEAD"))
          .resolves.toBe("commit");
      });
    });
    // We don't have any tags worth checking so we'll just have to believe.
    describe("when pointed at a tree", () => {
      test("resolves to `tree`", () => {
        return expect(git.objectType("HEAD:preview"))
          .resolves.toBe("tree");
      });
    });
    describe("when pointed at a missing file", () => {
      test("resolves to `missing`", () => {
        return expect(git.objectType("HEAD:totally_not_there"))
          .resolves.toBe("missing");
      });
    });
    describe("when pointed at a missing branch", () => {
      test("resolves to `missing`", () => {
        return expect(git.objectType("totally_missing_branch:template.html"))
          .resolves.toBe("missing");
      });
    });
  });

  describe("_streamChild", () => {
    describe("when running a successful child", () => {
      describe("without output", () => {
        test("returns an empty stream", () => {
          return expect(collect(git._streamChild(child_process.spawn("true"))))
            .resolves.toBe("");
        });
      });
      describe("with output", () => {
        test("returns the output", () => {
          return expect(collect(git._streamChild(child_process.spawn("echo", ["words"]))))
            .resolves.toBe("words\n");
        });
      });
    });
    describe("when the child says that an object is not valid", () => {
      test("emits `missing`", () => {
        return expect(collect(git._streamChild(child_process.spawn(
          "echo Not a valid object name 1>&2 && false", [], {shell: true})
        ))).rejects.toBe("missing");
      });
    });
    describe("when the child says that revision is invalid", () => {
      test("emits `missing`", () => {
        return expect(collect(git._streamChild(child_process.spawn(
          "echo fatal: bad revision 1>&2 && false", [], {shell: true})
        ))).rejects.toBe("missing");
      });
    });
    describe("when running a failing child", () => {
      test("emits an error", () => {
        return expect(collect(git._streamChild(child_process.spawn("false"))))
          .rejects.toBe("Child failed with code 1");
      });
    });
    describe("when the child is killed", () => {
      test("emits an error", () => {
        const child = child_process.spawn("sleep", ["1000"]);
        process.nextTick(() => child.kill());
        expect(collect(git._streamChild(child)))
          .rejects.toBe("Child died with signal SIGTERM");
      });
    });
  });

  describe("catBlobToString", () => {
    describe("when pointed at a blob", () => {
      test("returns the blob", () => {
        return expect(git.catBlobToString("HEAD:preview/git.js", 1024 * 1024))
          .resolves.toMatch(/catBlobToString:/);
      });
    });
    describe("when pointed at a missing file", () => {
      test("rejectes to `missing`", () => {
        return expect(git.catBlobToString("HEAD:totally_not_there", 1024))
          .rejects.toBe("missing");
      });
    });
    describe("when pointed at a missing branch", () => {
      test("rejects to `missing`", () => {
        return expect(git.catBlobToString("totally_missing_branch:template.html", 1024))
          .rejects.toBe("missing");
      });
    });
  });

  describe("catBlob", () => {
    describe("when the object is a blob", () => {
      test("it contains the body of the blob", () => {
        return expect(collect(git.catBlob("HEAD:preview/git.js")))
          .resolves.toMatch(/catBlob:/);
      });
    });
    describe("when the object is missing", () => {
      test("the stream contains an error", () => {
        return expect(collect(git.catBlob("HEAD:totally_not_here")))
          .rejects.toBe("missing");
      });
    });
    describe("when the branch is missing", () => {
      test("the stream contains an error", () => {
        return expect(collect(git.catBlob("totally_missing_branch:template.html")))
          .rejects.toBe("missing");
      });
    });
  });

  describe("diffLastCommit", () => {
    const tmp = "/tmp/preview_test_repo";
    const gitOpts = {
      cwd: tmp,
      env: {
        GIT_AUTHOR_NAME: "test",
        GIT_AUTHOR_EMAIL: "test@example.com",
        GIT_COMMITTER_NAME: "test",
        GIT_COMMITTER_EMAIL: "test@example.com",
      },
    };
    const collectDiff = async itr => {
      const result = [];
      for await (const change of itr) {
        result.push(change);
      }
      return result;
    };

    let diff;
    beforeAll(async () => {
      await rmfr(tmp);
      await mkdir(tmp);
      await execFile("git", ["init"], gitOpts);
      await writeFile(`${tmp}/removed`, "remove me");
      await writeFile(`${tmp}/renamed_from`, "rename me");
      await execFile("git", ["add", "."], gitOpts);
      await execFile("git", ["commit", "-m", "init"], gitOpts);
      await writeFile(`${tmp}/added`, "add me");
      await writeFile(`${tmp}/renamed_to`, "rename me");
      await unlink(`${tmp}/removed`);
      await unlink(`${tmp}/renamed_from`);
      await execFile("git", ["add", "."], gitOpts);
      await execFile("git", ["commit", "-m", "diff me"], gitOpts);
      diff = await collectDiff(Git(tmp).diffLastCommit("master"));
    });

    describe("when a file is added", () => {
      test("it shows the right diff", () => {
        expect(diff).toContainEqual({path: "added", added: "1", removed: "0"});
      });
    });
    describe("when a file is removed", () => {
      test("it shows the right diff", () => {
        expect(diff).toContainEqual({path: "removed", added: "0", removed: "1"});
      });
    });
    describe("when a file is moved", () => {
      test("it shows the right diff", () => {
        expect(diff).toContainEqual({
          path: "renamed_from",
          movedToPath: "renamed_to",
          added: "0",
          removed: "0"
        });
      });
    });
    describe("on a non-master branch", () => {
      let nonMasterDiff;
      beforeAll(async () => {
        await execFile("git", ["checkout", "-b", "testbranch"], gitOpts);
        await execFile("git", ["rm", "-f", "added"], gitOpts);
        await execFile("git", ["add", "."], gitOpts);
        await execFile("git", ["commit", "-m", "diff me too"], gitOpts);
        nonMasterDiff = await collectDiff(Git(tmp).diffLastCommit("testbranch"));
      });
      test("shows the correct branch", () => {
        expect(nonMasterDiff).toStrictEqual([{path: "added", added: "0", removed: "1"}]);
      });
    });
    describe("when the branch is missing", () => {
      test("the iterator yields an error", () => {
        return expect(collectDiff(git.diffLastCommit("totally_missing_branch")))
          .rejects.toBe("missing");
      });
    });
    describe("when the branch is missing", () => {
      test("the iterator yields an error", () => {
        return expect(collectDiff(git.diffLastCommit("totally_missing_branch")))
          .rejects.toBe("missing");
      });
    });
  });
  describe("_parseDiffTreeZ", () => {
    const parse = async (itr, destroy = () => {}) => {
      const result = [];
      for await (const change of git._parseDiffTreeZ(itr, destroy)) {
        result.push(change);
      }
      return result;
    };
    const smear = function* (str) {
      for (const c of [...str]) {
        yield Buffer.from(c);
      }
    };

    describe("when sent an empty iterator", () => {
      test("returns an empty diff", () => {
        return expect(parse((function*() {
          // Intentionally yield nothing
        })())).resolves.toStrictEqual([]);
      });
    });
    describe("when sent an iterator with just a commit hash", () => {
      test("returns an empty diff", () => {
        return expect(parse((function*() {
          yield Buffer.from("ba07ac2cbbeea5f68bef9188249fbf0ff7953e37\0");
        })())).resolves.toStrictEqual([]);
      });
    });
    describe("when sent an iterator containing a file that wasn't moved", () => {
      test("returns the file", () => {
        return expect(parse((function*() {
          yield Buffer.from("123\t334\tdon't move\0");
        })())).resolves.toStrictEqual([{path: "don't move", added: "123", removed: "334"}]);
      });
    });
    describe("when sent an iterator containing a file that was moved", () => {
      test("returns the file including it's destination", () => {
        return expect(parse((function*() {
          yield Buffer.from("123\t334\t\0src\0dest\0");
        })())).resolves.toStrictEqual([{path: "src", movedToPath: "dest", added: "123", removed: "334"}]);
      });
    });
    describe("when a commit hash line is in many chunks", () => {
      test("returns an empty diff", () => {
        return expect(parse(smear("ba07ac2cbbeea5f68bef9188249fbf0ff7953e37\0")))
          .resolves.toStrictEqual([]);
      });
    });
    describe("when a normal line is in many chunks", () => {
      test("returns the file", () => {
        return expect(parse(smear("123\t334\tdon't move\0")))
          .resolves.toStrictEqual([{path: "don't move", added: "123", removed: "334"}]);
      });
    });
    describe("when chunk has a weird number of tabs", () => {
      test("throws an error", () => {
        return expect(parse(smear("what\tis\tthis\tmadness\0")))
          .rejects.toThrow(/Strange entry fom git: what\tis\tthis\tmadness/);
      });
    });
    describe("when chunk has stuff after the last nul", () => {
      test("throws an error", () => {
        return expect(parse(smear("\0undeserving")))
          .rejects.toThrow(/Trailing garbage after diff: undeserving/);
      });
    });
    describe("when the generator throws an error", () => {
      test("throws an error", () => {
        return expect(parse((async function*() {
          throw new Error("testerr");
        })())).rejects.toThrow(/testerr/);
      });
    });
  });
});
