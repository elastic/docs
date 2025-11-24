const path = require('path');

module.exports = {
  plugins: [
    require('postcss-import')(),
    require('postcss-nested')(),
    require('postcss-assets')({
      loadPaths: [path.join(__dirname, 'style')],
    }),
  ],
};
