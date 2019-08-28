'use strict';

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
const dedent = require('dedent');
const http = require('http');
const stream = require('stream');
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
  const parsedUrl = url.parse(request.url);
  const branch = gitBranch(request.headers['host']);
  if (parsedUrl.pathname === '/diff') {
    serveDiff(branch, response);
    return;
  }
  if (!parsedUrl.pathname.startsWith('/guide')) {
    response.statusCode = 404;
    response.end();
    return;
  }
  const path = 'html' + parsedUrl.pathname.substring('/guide'.length);
  const requestedObject = `${branch}:${path}`;
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

    const child = child_process.spawn(
      'git', ['cat-file', 'blob', requestedObject], catOpts
    );
    rigHandlers(child, response, child.stdout, response => {});
  });
}

function serveDiff(branch, response) {
  const child = child_process.spawn(
    'git',
    ['diff-tree', '-z', '--find-renames', '--numstat', branch, '--'],
    catOpts
  );

  let chunk = '';
  let first = true;
  let completeSuccess = true;
  const handleChunk = () => {
    /*
     * Parses output from `git diff-tree -z` which is in
     * one of two formats:
     * * added lines<tab>removed lines<tab>path<nul>
     * * added lines<tab>removed lines<nul>source path<nul>destination path<nul>
     * The second one is only used when git detects a rename.
     */
    let out = '';
    let entryStart;
    let nextNul = -1;
    let added;
    let removed;
    let path;
    let movedToPath;

    if (first) {
      out = dedent `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Diff for ${branch}</title>
        </head>
        <body><ul>\n`
      first = false;
    }

    while (true) {
      /* When this loop starts nextNul is either -1 or the end of the last
       * message so we can pick up from nextNul + 1. */
      entryStart = nextNul + 1;
      nextNul = chunk.indexOf('\0', entryStart);
      if (nextNul === -1) {
        chunk = chunk.substring(entryStart);
        return out;
      }
      const parts = chunk.substring(entryStart, nextNul).trim().split('\t');
      switch (parts.length) {
      case 3:
        [added, removed, path] = parts;
        movedToPath = null;
        break;
      case 2:
        [added, removed] = parts;
        const pathStart = nextNul + 1;
        nextNul = chunk.indexOf('\0', pathStart);
        if (nextNul === -1) {
          chunk = chunk.substring(entryStart);
          return out;
        }
        path = chunk.substring(pathStart, nextNul);
        const moveToPathStat = nextNul + 1;
        nextNul = chunk.indexOf('\0', moveToPathStat);
        if (nextNul === -1) {
          chunk = chunk.substring(entryStart);
          return out;
        }
        movedToPath = chunk.substring(moveToPathStat, nextNul);
        break;
      case 1:
        // The commit hash. Ignore it.
        continue;
      default:
        console.warn("Unknown message from git", parts);
        completeSuccess = false;
        continue;
      }

      // Skip boring files
      if ([
            'html/branches.yaml', 'html/sitemap.xml',
          ].includes(path)) {
        continue;
      }

      // Strip the prefix from the paths
      path = path.substring('html/'.length);
      movedToPath =
        movedToPath === null ? null : movedToPath.substring('html/'.length);

      // Build the output html
      const diff = `+${added} -${removed}`;
      const linkText =
        movedToPath === null ? path : `${path} -> ${movedToPath}`;
      const linkTarget =
        "/guide/" + (movedToPath === null ? path : movedToPath);
      const link = `<a href="${linkTarget}">${linkText}</a>`;
      out += `  <li>${diff} ${link}\n`;
    }
  };

  const handle = new stream.Transform({
    writableObjectMode: true,
    transform(chunkIn, encoding, callback) {
      chunk += chunkIn;
      callback(null, handleChunk());
    }
  });

  const pipeline = child.stdout.pipe(handle);
  rigHandlers(child, response, pipeline, response => {
    response.write(handleChunk());
    if (chunk !== '') {
      console.error('unprocessed results from git', chunk);
      response.write(`  <li>Unprocessed results from git: <pre>${chunk}</pre>`);
      response.status = 500;
    } else if (!completeSuccess) {
      response.write(`  <li>Error processing some entries from git. See logs.`);
      response.status = 500;
    }
    response.write('</ul></html>');
  });
}

function rigHandlers(child, response, pipeline, endHandler) {
  response.setHeader('Transfer-Encoding', 'chunked');

  // We spool stderr into a string because it is never super big.
  child.stderr.setEncoding('utf8');
  let childstderr = '';
  child.stderr.addListener('data', chunk => {
    childstderr += chunk;
  });

  /* We end the response either when an error occurs or when *both* the child
   * process *and* its pipeline have been consumed. If we didn't wait for the
   * child process then we'd end early on failures. If we didn't wait for the
   * pipeline we could throw out the end of the response. */
  let childExited = false;
  let pipelineEnded = false;
  const checkForNormalEnd = () => {
    if (childExited && pipelineEnded) {
      endHandler(response);
      response.end();
    }
  }

  child.addListener('close', (code, signal) => {
    /* This can get invoked multiple times but we can only do anything
     * the first time so we just drop the second time on the floor. */
    if (childExited) return;
    childExited = true;

    if (code === 0 && signal === null) {
      checkForNormalEnd();
      return;
    }
    if (childstderr.includes('bad revision')) {
      response.statusCode = 404;
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

  pipeline.on('end', () => {
    pipelineEnded = true;
    checkForNormalEnd();
  });
  pipeline.pipe(response, {end: false});
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
