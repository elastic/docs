import Cookies from "../../../../../node_modules/js-cookie";
import {merge, toPairs, forEach} from "../../../../../node_modules/ramda";
import {closeModal} from "./modal";

const SAVE_SETTING = "SAVE_SETTING";

export const setCookies = forEach(([k, v]) => Cookies.set(k, v));

// this is used as a factory so we can mock it up during tests
// the function used in the app is setup below
export const _saveSettings = setCookies =>
  m => dispatch => {
    setCookies(toPairs(m));
    dispatch(closeModal());
    return dispatch({
      type: SAVE_SETTING,
      settings: m
    });
  };

export const saveSettings = _saveSettings(setCookies);

const initialState = {
  /*
    language: lang,
    langStrings: LangStrings,
    baseUrl: base_url,
    kibana_url,
    console_url,
    sense_url,
    curl_host: Cookies.get("curl_host") || "localhost:9200",
    curl_user: Cookies.get("curl_user"),
    curl_password: Cookies.get("curl_password")
  */
};

export const reducer = (state = initialState, action) => {
  switch (action.type) {
    case SAVE_SETTING:
      return merge(state, action.settings);
    default:
      return state;
  }
}
