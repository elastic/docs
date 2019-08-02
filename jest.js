var Enzyme = require('enzyme');
var Adapter = require('enzyme-adapter-preact-pure').default;
Enzyme.configure({ adapter: new Adapter });

var jQuery = require("jquery");
window.$ = window.jQuery = jQuery;
