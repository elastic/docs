import thunk from '../../../../node_modules/redux-thunk';
import { createStore, applyMiddleware } from '../../../../node_modules/redux';
import reducer from "./actions";

var __store;

export default (initialState) => {
  if (!__store) {
    __store = createStore(reducer, initialState, applyMiddleware(thunk));
  }

  return __store;
}
