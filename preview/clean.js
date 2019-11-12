'use strict';

const child_process = require('child_process');
const dedent = require('dedent');
const https = require('https');
const os = require('os');
const path = require('path');

module.exports = { Cleaner, exec_git };

const EXPIRE_DAYS = 31;

function Cleaner(token, repo, cache_dir, tmp_dir) {
  let repo_name = path.basename(repo);
  if (!repo_name.endsWith('.git')) {
    repo_name += '.git';
  }
  const local_path = `${tmp_dir}/${repo_name}`;

  const clone = () => {
    return exec_git([
      'clone',
      '--bare',
      '--reference', `${cache_dir}/${repo_name}`,
      repo, local_path])
  }

  const show_heads = () => {
    return exec_git(['show-ref', '--heads'], {cwd: local_path});
  }

  const heads_to_prs = (heads) => {
    return heads
      .split('\n')
      .reduce((acc, line) => {
        const found = line.match(/^.+ refs\/heads\/((.+)_(\d+))$/);
        if (found) {
          acc.push({
            branch: found[1],
            repo: found[2],
            number: Number(found[3]),
          });
        }
        return acc;
      }, [])
      .sort((lhs, rhs) => {
        if (lhs.repo < rhs.repo) {
          return -1;
        }
        if (lhs.repo > rhs.repo) {
          return 1;
        }
        return lhs.number - rhs.number;
      });
  }

  const cleanup_closed_prs = async prs => {
    const now = Date.now() / 1000;
    for (let pr of prs) {
      const url = `https://www.github.com/elastic/${pr.repo}/pull/${pr.number}`;
      const age = await prAge(pr);
      const days = (now - age) / 24 / 60 / 60;
      if (days > EXPIRE_DAYS) {
        console.log(`Deleting ${pr.branch} for ${days.toFixed(2)} days old pr at ${url}`);
        deleteBranch(pr);
      } else if (await is_pr_closed(pr)) {
        console.info(`Deleting ${pr.branch} for closed pr at ${url}`);
        deleteBranch(pr);
      } else {
        console.info(`Preserving ${pr.branch} for open pr at ${url}`);
      }
    }
  }

  const prAge = async function(pr) {
    return parseInt(await exec_git(
      [
        "show", "--pretty=%ad", "--no-notes", "--no-patch", "--date=unix",
        pr.branch
      ],
      {cwd: local_path}
    ));
  }

  const deleteBranch = async function(pr) {
    if (pr.branch === 'master' || pr.branch === 'staging') {
      // Just for super double ultra paranoia.
      throw "Can't delete master!";
    }
    await exec_git(
      ['push', 'origin', '--delete', pr.branch],
      {cwd: local_path}
    );
  }

  const is_pr_closed = function(pr) {
    return new Promise((resolve, reject) => {
      const body = {
        query: `
          query PRClosed($repo: String!, $number: Int!) {
            repository(owner:\"elastic\", name:$repo) {
              pullRequest(number:$number) {
                closed
              }
            }
          }
        `,
        variables: {
          repo: pr.repo,
          number: pr.number,
        },
      };
      const postData = JSON.stringify(body);
      const req = https.request({
        method: 'POST',
        host: 'api.github.com',
        path: '/graphql',
        headers: {
          'Authorization': `bearer ${token}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
          'User-Agent': 'Elastic Docs Preview Cleaner Upper',
        }
      }, res => {
        let data = '';
        res.on('data', chunk => {
          data += chunk;
        });
        res.on('end', () => {
          if (res.statusCode !== 200) {
            reject(`Error getting ${JSON.stringify(pr)} [${res.statusCode}]:\n${data}`);
          } else {
            let closed;
            try {
              const parsed = JSON.parse(data);
              const repo = parsed.data.repository;
              if (repo) {
                closed = repo.pullRequest.closed;
              } else {
                console.warn(pr.branch,
                  "looks like a PR but isn't for a repo we manage so we assume",
                  'it is open');
                closed = false;
              }
            } catch (e) {
              reject(e);
              return;
            }
            if (closed === undefined) {
              reject(`unexpected reply from github:${data}`);
              return;
            }
            if (res.headers['x-ratelimit-remaining'] < 100) {
              const until = res.headers['x-ratelimit-reset'];
              const millis = until * 1000 - Date.now().getTime();
              console.info('Rate limited for', millis, 'milliseconds');
              setTimeout(() => resolve(closed), millis);
            } else {
              resolve(closed);
            }
          }
        });
      });
      req.on('error', err => {
        reject(`Error getting ${JSON.stringify(pr)}:\n${err}`);
      });
      req.write(postData);
      req.end();
    });
  }

  return {
    run: () => {
      return clone()
        .then(show_heads)
        .then(heads_to_prs)
        .then(cleanup_closed_prs);
    },
    clone: clone,
    is_pr_closed: is_pr_closed,

    repo: repo,
    local_path: local_path,
  };
}

function exec_git(opts, env = {}) {
  return new Promise((resolve, reject) => {
    child_process.execFile('git', opts, env, (err, stdout, stderr) => {
      if (err) {
        reject(dedent `
          err [${err}] running [git ${opts.join(' ')}] in ${JSON.stringify(env)}:
          ${stderr}
        `);
      } else {
        resolve(stdout);
      }
    });
  });
}

if (require.main === module) {
  const token = process.env['GITHUB_TOKEN']
  const cache_dir = process.env['CACHE_DIR'];
  const repo = process.argv[2];

  process.on('SIGINT', () => {
    process.exit(1);
  });

  new Cleaner(token, repo, cache_dir, os.tmpdir()).run()
    .catch(err => {
      console.error(err);
      process.exit(1);
    });
}