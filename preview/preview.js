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
  'encoding': 'buffer',
  'max_buffer': 1024 * 1024 * 20,
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
    const showGitObject = gitShowObject(requestedObject, stdout.trim());
    child_process.execFile('git', ['cat-file', 'blob', showGitObject], catOpts, (err, stdout, stderr) => {
      if (err) {
        console.warn('unhandled error', err);
        response.statusCode = 500;
        response.end(err.message);
        return;
      }
      response.end(stdout);
    });
  });
}

function gitShowObject(requestedObject, type) {
  switch (type) {
    case 'tree':
      const sep = requestedObject.endsWith('/') ? '' : '/';
      return `${requestedObject}${sep}index.html`;
    case 'blob':
      return requestedObject;
    default:
      console.warn('received request for object of type', type, 'at', requestedObject);
      return 'HEAD:html/en/index.html';
  }
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
