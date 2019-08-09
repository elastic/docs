import {combineReducers} from "../../../../../node_modules/redux";
import {reducer as settingsReducer} from "./settings";
import {reducer as modalReducer} from "./modal";

export default combineReducers({
  settings: settingsReducer,
  modal: modalReducer
})
