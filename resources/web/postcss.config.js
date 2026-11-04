const path = require('path');

module.exports = {
  plugins: [
    require('precss')(),
    require('postcss-assets')({
      // `inline("img/foo.svg")` is relative to the style directory.
      basePath: __dirname,
      loadPaths: ['style/'],
    }),
  ],
};
