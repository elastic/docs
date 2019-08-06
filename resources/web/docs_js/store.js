import thunk from '../../../../node_modules/redux-thunk';
import { createStore, applyMiddleware } from '../../../../node_modules/redux';
import reducer from "./actions";

export const newStore = initialState =>
  createStore(reducer, initialState, applyMiddleware(thunk));

export default initialState => {
  if (!window.__reduxStore) {
    window.__reduxStore = newStore(initialState);
  }

  return window.__reduxStore;
}
