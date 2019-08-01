import { Provider } from '../../../../../node_modules/preact-redux';
import { h, render } from '../../../../../node_modules/preact';
import store from "../store";

export default (domEl, Component, opts = {}) => {
  return render(
    (<Provider store={store()}>
       <Component {...opts} />
     </Provider>)
  , domEl[0]);
}
