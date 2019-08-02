import thunk from '../../../../node_modules/redux-thunk';
import { createStore, applyMiddleware } from '../../../../node_modules/redux';
import reducer from "./actions";

var __store;

export const newStore = initialState =>
  createStore(reducer, initialState, applyMiddleware(thunk));

export default initialState => {
  if (!__store) {
    __store = newStore(initialState);
  }

  return __store;
}
