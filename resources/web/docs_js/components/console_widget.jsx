import * as utils from "../utils.js";
import {pick, merge} from "../../../../../node_modules/ramda";
import {h, Component} from "../../../../../node_modules/preact";
import linkState from "../../../../../node_modules/linkstate";
import {connect} from "../../../../../node_modules/preact-redux";
import {openModal} from "../actions/modal";
import {saveSettings} from "../actions/settings";
import Modal from "./modal";

const copyAsCurl = ({consoleText, isKibana}) => (_, getState) => {
  const state = getState();
  const settings = pick(["langStrings",
                         "curl_host",
                         "curl_user",
                         "curl_password"], state.settings);

  const curlText = utils.getCurlText(merge(settings, {consoleText, isKibana}))

  return utils.copyText(curlText, settings.langStrings);
}

export class _ConsoleForm extends Component {
  componentWillMount() {
    if (this.props.console_url) {
      this.setState({console_url: this.props.console_url,
                     curl_host: this.props.curl_host,
                     curl_user: this.props.curl_user,
                     curl_password: this.props.curl_password})
    }
  }

  render(props, state) {
    return <form>
      <label for="url">{props.langStrings('Enter the URL of the Console editor')}</label>
      <input id="url" type="text" value={state.console_url} onInput={linkState(this, "console_url")} />

      <label for="curl_host">cURL Host</label>
      <input id="curl_host" type="text" value={state.curl_host} onInput={linkState(this, "curl_host")} />

      <label for="curl_username">cURL Username</label>
      <input id="curl_username" type="text" value={state.curl_user} onInput={linkState(this, "curl_user")} />

      <label for="curl_pw">cURL Password</label>
      <input id="curl_pw" type="text" value={state.curl_password} onInput={linkState(this, "curl_password")} />

      <button id="save_url" type="button" onClick={e => props.saveSettings(this.state)}>
        {props.langStrings("Save")}
      </button>

      <button id="reset" onClick={e => this.setState({console_url: props.console_url,
                                                          curl_host: props.curl_host,
                                                          curl_user: props.curl_user,
                                                          curl_password: props.curl_password})} type="button">Reset</button>
      <p>
        {props.langStrings('Or install')}
        <a href="https://www.elastic.co/guide/en/kibana/master/setup.html">Kibana</a>{props.langStrings('.')}
      </p>
    </form>
  }
}

export const ConsoleForm = connect(state =>
  pick(["langStrings",
        "console_url",
        "curl_host",
        "curl_user",
        "curl_password"], state.settings)
, {saveSettings})(_ConsoleForm);

export const ConsoleWidget = props => {
  return <div>
    <a className="sense_widget copy_as_curl"
       onClick={e => props.copyAsCurl({consoleText: props.consoleText,
                                       isKibana: props.isKibana})}>
      {props.langStrings('Copy as cURL')}
    </a>
    <a className="console_widget"
       target="console"
       title={props.langStrings(props.widgetTitle)}
       href={`${props.console_url}?load_from=${props.baseUrl}${props.snippet}`}>{props.langStrings(props.widgetText)}</a>
    <a className="console_settings" onClick={props.openModal} title={props.langStrings(props.consoleTitle)}>&nbsp;</a>
    <Modal><ConsoleForm /></Modal>
  </div>
}

export default connect(state =>
  pick(["langStrings", "baseUrl", "console_url"], state.settings)
, {copyAsCurl, openModal})(ConsoleWidget)
