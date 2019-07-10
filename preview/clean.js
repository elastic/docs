'use strict';

const child_process = require('child_process');
const dedent = require('dedent');
const https = require('https');
const os = require('os');
const path = require('path');

module.exports = Cleaner;
module.exports.exec_git = exec_git;

function Cleaner(token, repo, cache_dir, tmp_dir) {
  this.repo = repo;
  let repo_name = path.basename(repo);
  if (!repo_name.endsWith('.git')) {
    repo_name += '.git';
  }
  this.local_path = `${tmp_dir}/${repo_name}`;

  this.run = () => {
    return this.clone()
      .then(this.show_heads)
      .then(this.heads_to_prs)
      .then(this.cleanup_closed_prs);
  }

  this.clone = () => {
    return exec_git([
      'clone',
      '--bare',
      '--reference', `${cache_dir}/${repo_name}`,
      repo, this.local_path])
  }

  this.show_heads = () => {
    return exec_git(['show-ref', '--heads'], {cwd: this.local_path});
  }

  this.heads_to_prs = (heads) => {
    return heads
      .split('\n')
      .map(line => {
        const found = line.match(/^.+ refs\/heads\/((.+)_(\d+))$/);
        if (found) {
          return {
            branch: found[1],
            repo: found[2],
            number: Number(found[3]),
          };
        }
      })
      .filter(a => a)
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

  this.cleanup_closed_prs = async prs => {
    for (let pr of prs) {
      const url = `https://www.github.com/elastic/${pr.repo}/pull/${pr.number}`;
      if (await this.is_pr_closed(pr)) {
        console.info(`Deleting ${pr.branch} for closed pr at ${url}`);
        if (pr.branch === 'master' || pr.branch === 'staging') {
          // Just for super double ultra paranoia.
          throw "Can't delete master!";
        }
        await exec_git(
          ['push', 'origin', '--delete', pr.branch],
          {cwd: this.local_path}
        );
      } else {
        console.info(`Preserving ${pr.branch} for open pr at ${url}`);
      }
    }
  }

  this.is_pr_closed = function(pr) {
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
              closed = parsed.data.repository.pullRequest.closed;
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
              console.info('rate limited for', millis, 'milliseconds');
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