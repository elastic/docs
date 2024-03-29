import * as utils from "../utils";
import {prop, pick, merge, omit} from "../../../../../node_modules/ramda";
import {h, Component} from "../../../../../node_modules/preact";
import linkState from "../../../../../node_modules/linkstate";
import {connect} from "../../../../../node_modules/preact-redux";
import {openModal} from "../actions/modal";
import {saveSettings} from "../actions/settings";
import AlternativePicker from "./alternative_picker";

const copyAsCurl = ({setting, consoleText, isKibana, addPretty}) => (_, getState) => {
  const state       = getState();
  const langStrings = state.settings.langStrings;

  const curlVals = {
    curl_host:     prop(setting + "_curl_host", state.settings),
    curl_user:     prop(setting + "_curl_user", state.settings),
    curl_password: prop(setting + "_curl_password", state.settings)
  };

  const curlText = utils.getCurlText(merge(curlVals, {consoleText, isKibana, addPretty}))
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

      <label for="curl_host">curl {props.langStrings('host')}</label>
      <input id="curl_host" type="text" value={getValueFromState("curl_host")} onInput={linkState(this, getFieldName("curl_host"))} />

      <label for="curl_username">curl {props.langStrings('username')}</label>
      <input id="curl_username" type="text" value={getValueFromState("curl_user")} onInput={linkState(this, getFieldName("curl_user"))} />

      {/* TODO
      <label for="curl_pw" title={props.langStrings("curl_pw_title")}>curl {props.langStrings('password')}</label>
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

export class _TryConsoleSelector extends Component {
  componentWillMount() {
    const defaultVals = omit(['langStrings', 'saveSettings', 'url_label', 'setting'], this.props);
    this.setState(defaultVals);
  }


  render(props) {
    const handleConfigureClick = (e) => {
      e.preventDefault();
      props.settingsModalAction();
    }

    return (
      <div className="try_console_selector">
        <h4>Try in Console</h4>
        <p>We were unable to detect a running console server.</p>
        <p>
          <a
            id="try_console_selector_try_cloud_button"
            className="button btn-primary btn-small"
            href="https://cloud.elastic.co/registration"
            target="_blank"
          >
            Sign up for Elastic Cloud trial
          </a>
        </p>
        <p>
          <a
            id="try_console_selector_install_elasticsearch_button"
            href="https://www.elastic.co/guide/en/elasticsearch/reference/current/setup.html"
            target="_blank"
          >
            Install Elasticsearch and Kibana locally
          </a>
        </p>
        <p>
          <a
            id="try_console_selector_configure_example_widget_button"
            href="#"
            onClick={handleConfigureClick}
          >
            Configure the example widget
          </a>
        </p>
      </div>
    )
  }
}

export const ConsoleForm = connect((state, props) =>
  pick(["langStrings",
        `${props.setting}_url`,
        `${props.setting}_curl_host`,
        `${props.setting}_curl_user`,
        `${props.setting}_curl_password`], state.settings)
, {saveSettings})(_ConsoleForm);

export const TryConsoleSelector = connect((state, props) =>
  pick(["langStrings",
        `${props.setting}_url`,
        `${props.setting}_curl_host`,
        `${props.setting}_curl_user`,
        `${props.setting}_curl_password`], state.settings)
, {saveSettings})(_TryConsoleSelector);

// ConsoleWidget isn't quite the right name for this any more....
export const ConsoleWidget = props => {
  const settingsModalAction = () => props.openModal(ConsoleForm, {setting: props.setting, url_label: props.url_label});
  const openConsoleModal = () =>
    props.openModal(TryConsoleSelector, { settingsModalAction })
  const consoleModalAction = (e) => {
    e.preventDefault();
    const target = e.target;

    utils.checkServerStatus(target.href)
      .then((isUp) => {
        if (isUp) {
          window.open(target.href)
        } else {
          openConsoleModal();
        }
      })
      .catch((_) => {
        openConsoleModal();
      });
  };

  return (
    <div className="u-space-between">
      <AlternativePicker langs={props.langs} />
      <div className="u-space-between">
        <a
          className="sense_widget copy_as_curl"
          onClick={(e) =>
            props.copyAsCurl({
              isKibana: props.isKibana,
              consoleText: props.consoleText,
              setting: props.setting,
              addPretty: props.addPretty,
            })
          }
        >
          {props.langStrings('Copy as curl')}
        </a>
        {props.view_in_text && (
          <a
            className="view_in_link"
            target="console"
            onClick={(e) => consoleModalAction(e)}
            title={props.langStrings(props.view_in_text)}
            href={`${props[props.setting + "_url"]}?load_from=${props.baseUrl}${props.snippet}`}
          >
            {props.langStrings(props.view_in_text)}
          </a>
        )}
        <a
          className="console_settings"
          onClick={settingsModalAction}
          title={props.langStrings(props.configure_text)}
        >
          &nbsp;
        </a>
      </div>
    </div>
  )
}

export default connect(
  (state, props) => pick(["langStrings", "baseUrl", `${props.setting}_url`], state.settings),
  {copyAsCurl, openModal, saveSettings}
)(ConsoleWidget);
