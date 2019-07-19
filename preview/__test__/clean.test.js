'use strict';

const { Cleaner, exec_git } = require('../clean.js');
const fs = require('fs').promises;
const nock = require('nock');
const os = require('os');
const rmfr = require('rmfr');

const tmp = `${os.tmpdir()}/preview_cleaner`;

async function prepare_cleaner(extra_branches = []) {
  await fs.mkdir(tmp, {recursive: true});

  // Create an empty repo
  const repo = await fs.mkdtemp(`${tmp}/input`);
  const opts = {
    cwd: repo,
    env: {
      'GIT_AUTHOR_NAME': 'Test',
      'GIT_AUTHOR_EMAIL': 'test@example.com',
      'GIT_COMMITTER_NAME': 'Test',
      'GIT_COMMITTER_EMAIL': 'test@example.com',
    },
  };
  await exec_git(['init'], opts);
  await exec_git(['commit', '--allow-empty', '-m', 'init'], opts);
  for (let branch of extra_branches) {
    await exec_git(['branch', branch], opts);
  }

  // Create the local cache which is required by the cleaner scripit
  const cache_dir = await fs.mkdtemp(`${tmp}/cache`);
  opts.cwd = cache_dir;
  await exec_git(['clone', '--mirror', repo], opts);

  // Setup the cleaner
  const tmp_dir = await fs.mkdtemp(`${tmp}/tmp`);
  return new Cleaner(null, repo, cache_dir, tmp_dir);
}
function mock_github(request_body) {
  return nock('https://api.github.com').post('/graphql', request_body);
}
function github_result(is_closed) {
  return JSON.stringify({
    data: {
      repository: {
        pullRequest: {
          closed: is_closed
        }
      }
    }
  });
}

afterAll(() => rmfr(tmp));

describe('Cleaner.clone', () => {
  let out;
  beforeAll(async () => {
    const cleaner = await prepare_cleaner();
    await cleaner.clone();
    out = cleaner.local_path;
  });
  test('performs a bare clone', async () => {
    // We want a bare clone because it is a lot faster. We don't need to check
    // out all of the files in the master branch to do our job.
    await fs.access(out);
    await expect(fs.access(`${out}/.git`)).rejects.toMatchObject({
      code: 'ENOENT'
    });
  });
});

describe('Cleaner.is_pr_closed', () => {
  let cleaner;
  let token;
  beforeEach(() => {
    token = Math.random().toString();
    cleaner = new Cleaner(token, 'repo', null, null);
  });
  test('returns true if github returns true', async () => {
    mock_github().reply(200, github_result(true));
    await expect(cleaner.is_pr_closed({repo: 'r', number: 1})).resolves.toBe(true);
  });
  test('returns false if github returns false', async () => {
    mock_github().reply(200, github_result(false));
    await expect(cleaner.is_pr_closed({repo: 'r', number: 1})).resolves.toBe(false);
  });
  test('complains if github returns invalid json', async () => {
    mock_github().reply(200, 'pure garbage');
    await expect(cleaner.is_pr_closed({repo: 'r', number: 1})).rejects
      .toThrow(/Unexpected token p/);
  });
  test('complains if github returns unexpect json', async () => {
    mock_github().reply(200, JSON.stringify({
      data: {
        whatever: 'asdf'
      }
    }));
    await expect(cleaner.is_pr_closed({repo: 'r', number: 1})).rejects
      .toThrow(/Cannot read property 'pullRequest'/);
  });
  test("backs off if there aren't many requests remaining", async () => {
    // Mock setTimeout to immediately run. We don't use jest.useFakeTimers
    // because that needs to be manually advanced which is complex for this
    // test and not worth it.
    global.setTimeout = jest.fn((callback) => callback());
    Date.now = jest.fn(() => new Date(0));
    mock_github().reply(200, github_result(true), {
      'x-ratelimit-remaining': 50,
      'x-ratelimit-reset': 1,
    });
    const is_closed = cleaner.is_pr_closed({repo: 'r', number: 1});
    await expect(is_closed).resolves.toBe(true);
    expect(setTimeout).toHaveBeenCalledTimes(1);
    expect(setTimeout).toHaveBeenLastCalledWith(expect.any(Function), 1000);
  });
});

describe('Cleaner.run', () => {
  let repo;
  beforeAll(async () => {
    const cleaner = await prepare_cleaner(['staging', 'foo', 'r_1', 'r_2']);
    mock_github(/{"repo":"r","number":1}/).reply(200, github_result(false))
    mock_github(/{"repo":"r","number":2}/).reply(200, github_result(true))
    await cleaner.run();
    repo = cleaner.repo;
  });
  function show_branch(branch) {
    return exec_git(
      ['show-ref', '--verify', `refs/heads/${branch}`],
      {cwd:repo}
    );
  }
  test("branches that don't look like PRs are left alone", async () => {
    await expect(show_branch('master')).resolves.toMatch(/master/);
    await expect(show_branch('staging')).resolves.toMatch(/staging/);
  });
  test('branches for open prs are left alone', async () => {
    await expect(show_branch('r_1')).resolves.toMatch(/r_1/);
  });
  test('branches for closed prs are removed', async () => {
    await expect(show_branch('r_2')).rejects.toMatch(/not a valid ref/);
  });
});