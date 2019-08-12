import * as utils from "../utils";
import {prop, pick, merge, omit} from "../../../../../node_modules/ramda";
import {h, Component} from "../../../../../node_modules/preact";
import linkState from "../../../../../node_modules/linkstate";
import {connect} from "../../../../../node_modules/preact-redux";
import {openModal} from "../actions/modal";
import {saveSettings} from "../actions/settings";

const copyAsCurl = ({setting, consoleText, isKibana}) => (_, getState) => {
  const state       = getState();
  const langStrings = state.settings.langStrings;

  const curlVals = {
    curl_host:     prop(setting + "_curl_host", state.settings),
    curl_user:     prop(setting + "_curl_user", state.settings),
    curl_password: prop(setting + "_curl_password", state.settings)
  };

  const curlText = utils.getCurlText(merge(curlVals, {consoleText, isKibana, langStrings}))
  return utils.copyText(curlText, langStrings);
}

export class _ConsoleForm extends Component {
  componentWillMount() {
    const defaultVals = omit(['langStrings', 'saveSettings', 'url_label', 'setting'], this.props);
    this.setState(defaultVals);
  }

  render(props, state) {
    const getValueFromState = field => state[`${props.setting}_${field}`]
    const getFieldName = field => `${props.setting}_${field}`

    return <form>
      <label for="url">{props.langStrings(props.url_label)}</label>
      <input id="url" type="text" value={getValueFromState("url")} onInput={linkState(this, getFieldName("url"))} />

      <label for="curl_host">cURL {props.langStrings('host')}</label>
      <input id="curl_host" type="text" value={getValueFromState("curl_host")} onInput={linkState(this, getFieldName("curl_host"))} />

      <label for="curl_username">cURL {props.langStrings('username')}</label>
      <input id="curl_username" type="text" value={getValueFromState("curl_user")} onInput={linkState(this, getFieldName("curl_user"))} />

      {/* TODO
      <label for="curl_pw" title={props.langStrings("curl_pw_title")}>cURL {props.langStrings('password')}</label>
      <input id="curl_pw" title={props.langStrings("curl_pw_title")} type="text" value={getValueFromState("curl_password")} onInput={linkState(this, getFieldName("curl_password"))} />
       */}
      <button id="save_url" type="button" onClick={e => props.saveSettings(this.state)}>
        {props.langStrings("Save")}
      </button>

      <button id="reset" onClick={e => this.setState(omit(['langStrings', 'saveSettings', 'url_label', 'setting'], props))} type="button">Reset</button>
      <p>
        {props.langStrings('Or install')}
        {props.setting === "sense_url"
         ? <a href="https://www.elastic.co/guide/en/sense/current/installing.html">the Sense 2 {props.langStrings('editor')}</a>
         : <a href="https://www.elastic.co/guide/en/kibana/master/setup.html">Kibana</a>
        }
         {props.langStrings('.')}
      </p>
    </form>
  }
}

export const ConsoleForm = connect((state, props) =>
  pick(["langStrings",
        `${props.setting}_url`,
        `${props.setting}_curl_host`,
        `${props.setting}_curl_user`,
        `${props.setting}_curl_password`], state.settings)
, {saveSettings})(_ConsoleForm);

export const ConsoleWidget = props => {
  const modalAction = () => props.openModal(ConsoleForm, {setting: props.setting, url_label: props.url_label});
  return <div>
    <a className="sense_widget copy_as_curl"
       onClick={e => props.copyAsCurl({isKibana: props.isKibana, consoleText: props.consoleText, setting: props.setting})}>
      {props.langStrings('Copy as cURL')}
    </a>
    {props.view_in_text &&
      <a className="view_in_link"
         target="console"
         title={props.langStrings(props.view_in_text)}
         href={`${props[props.setting + "_url"]}?load_from=${props.baseUrl}${props.snippet}`}>{props.langStrings(props.view_in_text)}</a>
    }
    <a className="console_settings" onClick={modalAction} title={props.langStrings(props.configure_text)}>&nbsp;</a>
  </div>
}

export default connect((state, props) =>
  pick(["langStrings", "baseUrl", `${props.setting}_url`], state.settings)
, {copyAsCurl, openModal})(ConsoleWidget)
