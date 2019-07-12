/*
 * Little server that listens for requests in the form of
 * `${branch}.host/guide/${doc}`, looks up the doc from git and streams
 * it back over the response.
 *
 * It uses subprocesses to access git. It is tempting to use NodeGit to prevent
 * the fork overhead but for the most part the subprocesses are fast enough and
 * I'm worried that NodeGit's `Blog.getContent` methods are synchronous.
 */

const child_process = require('child_process');
const http = require('http');
const url = require('url');

const port = 3000;
const checkTypeOpts = {
  'cwd': '/docs_build/.repos/target_repo.git',
  'max_buffer': 64,
};
const catOpts = {
  'cwd': '/docs_build/.repos/target_repo.git',
};

const requestHandler = (request, response) => {
  parsedUrl = url.parse(request.url);
  if (!parsedUrl.pathname.startsWith('/guide')) {
    response.statusCode = 404;
    response.end();
    return;
  }
  const path = 'html' + parsedUrl.pathname.substring('/guide'.length);
  const branch = gitBranch(request.headers['host']);
  const requestedObject = `${branch}:${path}`;
  // TODO keepalive?
  // TODO include the commit info for the branch in a header
  child_process.execFile('git', ['cat-file', '-t', requestedObject], checkTypeOpts, (err, stdout, stderr) => {
    if (err) {
      if (err.message.includes('Not a valid object name')) {
        response.statusCode = 404;
        response.end(`Can't find ${requestedObject}\n`);
      } else {
        console.warn('unhandled error', err);
        response.statusCode = 500;
        response.end(err.message);
      }
      return;
    }

    if (stdout.trim() === 'tree') {
      response.statusCode = 301;
      const sep = requestedObject.endsWith('/') ? '' : '/';
      response.setHeader('Location', `${parsedUrl.pathname}${sep}index.html`);
      response.end();
      return;
    }

    response.setHeader('Transfer-Encoding', 'chunked');
    const child = child_process.spawn(
      'git', ['cat-file', 'blob', requestedObject], catOpts
    );

    // We spool stderr into a string because it is never super big.
    child.stderr.setEncoding('utf8');
    let childstderr = '';
    child.stderr.addListener('data', chunk => {
      childstderr += chunk;
    });

    /* Let node handle all the piping because it handles backpressure properly.
     * We don't let the pipe emit the `end` event though because we'd like to
     * do that manually when the process exits. The chunk size seems looks like
     * it is 4k which looks to come from the child_process. */
    child.stdout.pipe(response, {end: false});

    let exited = false;
    child.addListener('close', (code, signal) => {
      /* This can get invoked multiple times but we can only do anything
       * the first time so we just drop the second time on the floor. */
      if (exited) return;
      exited = true;

      if (code === 0 && signal === null) {
        response.end();
        return;
      }
      /* Note that we're playing a little fast and loose here with the status.
       * If we've already sent a chunk we can't change the status code. We're
       * out of luck. We just terminate the response anyway. The server log
       * is the best we can do for tracking these. */
      console.warn('unhandled error', code, signal, childstderr);
      response.statusCode = 500;
      response.end(childstderr);
    });
    child.addListener('error', err => {
      child.stdout.destroy();
      child.stderr.destroy();
      console.warn('unhandled error', err);
      response.statusCode = 500;
      response.end(err.message);
    });
  });
}

function gitBranch(host) {
  if (!host) {
    return 'master';
  }
  return host.split('.')[0];
}

const server = http.createServer(requestHandler);

server.listen(port, (err) => {
  if (err) {
    return console.info("preview server couldn't listen", err);
  }

  console.info(`preview server is listening on ${port}`);
});

process.on('SIGTERM', () => {
  console.info('preview server shutting down');
  server.close(() => {
    process.exit();
  });
});
