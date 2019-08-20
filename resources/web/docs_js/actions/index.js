import {combineReducers} from "../../../../../node_modules/redux";
import {reducer as settingsReducer} from "./settings";
import {reducer as modalReducer} from "./modal";

export default combineReducers({
  alternatives: (state = null, _action) => state,
  settings: settingsReducer,
  modal: modalReducer
})
