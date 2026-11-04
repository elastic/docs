import jQuery from 'jquery';

// In the browser jQuery is a global, loaded from its own script tag.
if (typeof window !== 'undefined') {
  window.$ = window.jQuery = jQuery;
  // Importing `index-v1.js` registers `$(document).ready` handlers that only
  // make sense on a real docs page. Hold them back so they don't throw.
  jQuery.holdReady(true);
}
