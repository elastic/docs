const path = require('path');

module.exports = {
  plugins: [
    require('postcss-import')(),
    require('precss')(),
    require('postcss-assets')({
      loadPaths: [path.join(__dirname, 'style')],
    }),
  ],
};
