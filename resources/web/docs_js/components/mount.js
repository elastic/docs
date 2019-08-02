import { Provider } from '../../../../../node_modules/preact-redux';
import { h, render } from '../../../../../node_modules/preact';
import store from "../store";

export const mount = ({el, Component, props = {}, store}) =>
  render(
    (<Provider store={store}>
       <Component {...props} />
     </Provider>)
    , el);

export default (domEl, Component, opts = {}) =>
  mount({el: domEl[0], Component, props: opts, store: store()});
