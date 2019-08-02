import * as utils from "../utils";
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

  if (isKibana) {
    settings.curl_host = state.settings.kibana_url;
  }

  const curlText = utils.getCurlText(merge(settings, {consoleText, isKibana}))

  return utils.copyText(curlText, settings.langStrings);
}

export class _ConsoleForm extends Component {
  componentWillMount() {
    if (this.props.console_url) {
      this.setState({[this.props.setting]: this.props[this.props.setting],
                     curl_host: this.props.curl_host,
                     curl_user: this.props.curl_user,
                     curl_password: this.props.curl_password})
    }
  }

  render(props, state) {
    return <form>
      <label for="url">{props.langStrings(props.url_label)}</label>
      <input id="url" type="text" value={state[props.setting]} onInput={linkState(this, props.setting)} />

      <label for="curl_host">cURL {props.langStrings('host')}</label>
      <input id="curl_host" type="text" value={state.curl_host} onInput={linkState(this, "curl_host")} />

      <label for="curl_username">cURL {props.langStrings('username')}</label>
      <input id="curl_username" type="text" value={state.curl_user} onInput={linkState(this, "curl_user")} />

      <label for="curl_pw">cURL {props.langStrings('password')}</label>
      <input id="curl_pw" type="text" value={state.curl_password} onInput={linkState(this, "curl_password")} />

      <button id="save_url" type="button" onClick={e => props.saveSettings(this.state)}>
        {props.langStrings("Save")}
      </button>

      <button id="reset" onClick={e => this.setState({[props.setting]: props[props.setting],
                                                      curl_host: props.curl_host,
                                                      curl_user: props.curl_user,
                                                      curl_password: props.curl_password})} type="button">Reset</button>
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
        props.setting,
        "curl_host",
        "curl_user",
        "curl_password"], state.settings)
, {saveSettings})(_ConsoleForm);

export const ConsoleWidget = props => {
  return <div>
    <a className="sense_widget copy_as_curl"
       onClick={e => props.copyAsCurl({consoleText: props.consoleText})}>
      {props.langStrings('Copy as cURL')}
    </a>
    {props.view_in_text &&
      <a className="console_widget"
         target="console"
         title={props.langStrings(props.view_in_text)}
         href={`${props[props.setting]}?load_from=${props.baseUrl}${props.snippet}`}>{props.langStrings(props.view_in_text)}</a>
    }
    <a className="console_settings" onClick={props.openModal} title={props.langStrings(props.configure_text)}>&nbsp;</a>
    <Modal>
      <ConsoleForm setting={props.setting} url_label={props.url_label} />
    </Modal>
  </div>
}

export default connect((state, props) =>
  pick(["langStrings", "baseUrl", props.setting], state.settings)
, {copyAsCurl, openModal})(ConsoleWidget)
