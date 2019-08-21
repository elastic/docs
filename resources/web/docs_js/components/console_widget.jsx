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

const alternativePrettyName = rawName => {
  switch(rawName) {
    case 'console': return 'Console';
    case 'csharp': return 'C#';
    case 'js': return 'JavaScript';
    case 'php': return 'PHP';
    default: return rawName;
  }
};

const AlternativeChoice = ({name: name}) => {
  return <option value={name}>{alternativePrettyName(name)}</option>;
};

export const _AlternativePicker = ({
  alternatives: alternatives,
  consoleAlternative: consoleAlternative,
  saveSettings: saveSettings,
}) => {
  if (!alternatives) {
    return <div/>; // Empty div to preserve the spacing
  }
  const consoleAlternatives = alternatives.console;
  if (!consoleAlternatives) {
    return <div/>;
  }

  const items = [];
  let sawChoice = 'console' === consoleAlternative;
  items.push(<AlternativeChoice name='console'/>);
  for (const name of Object.keys(consoleAlternatives)) {
    sawChoice |= name === consoleAlternative;
    items.push(<AlternativeChoice name={name} />);
  }

  /* If value isn't in the list then *make* it and we'll render our standard
   * "there no example for this language" option. This prevents us from
   * squashing preferences that users set. */
  if (!sawChoice) {
    items.push(<AlternativeChoice name={consoleAlternative} />);
  }
  // TODO we shouldn't change these drop downs after the first time they are rendered. The extra choice should stay while you stay on the page. Maybe we can get away with rendering this once on page load and never subscribing again?

  // TODO add the "message" bubble to the warning.
  // TODO prevent "jumping" when the size of the snippets isn't the same
  return <div className="AlternativePicker u-space-between">
    <select className="AlternativePicker-select"
            value={consoleAlternative}
            onChange={(e) => saveSettings({consoleAlternative: e.target.value})}>
      {items}
    </select>
    <div className="AlternativePicker-warning" />
  </div>;
};

// TODO move me to my own file
const AlternativePicker = connect(
  (state, props) => merge(
    pick(["consoleAlternative"], state.settings),
    {alternatives: state.alternatives}),
  {saveSettings})(_AlternativePicker)

// ConsoleWidget isn't quite the right name for this any more....
export const ConsoleWidget = props => {
  const modalAction = () => props.openModal(ConsoleForm, {setting: props.setting, url_label: props.url_label});
  return <div className="u-space-between">
    <AlternativePicker />
    <div>
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
  </div>
}

export default connect(
  (state, props) => pick(["langStrings", "baseUrl", `${props.setting}_url`], state.settings),
  {copyAsCurl, openModal, saveSettings}
)(ConsoleWidget);
