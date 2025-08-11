import { Provider } from 'preact-redux';
import { h, render } from 'preact';
import store from "../store";

export const mount = ({el, Component, props = {}, store}) =>
  render(
    (<Provider store={store}>
       <Component {...props} />
     </Provider>)
    , el);

export default (domEl, Component, opts = {}) =>
  mount({el: domEl[0], Component, props: opts, store: store()});
