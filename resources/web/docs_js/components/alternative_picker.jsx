/*
 * Widget allowing folks to the pick which client language they'd like to see
 * instead of "Console".
 */

import {h} from "../../../../../../node_modules/preact";
import {pick, merge} from "../../../../../node_modules/ramda";
import {connect} from "../../../../../node_modules/preact-redux";
import {saveSettings} from "../actions/settings";

const alternativePrettyName = rawName => {
  switch(rawName) {
    case "console": return "Console";
    case "csharp": return "C#";
    case "js": return "JavaScript";
    case "php": return "PHP";
    case "python": return "Python";
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
  return <div className="AlternativePicker u-space-between">
    <select className="AlternativePicker-select"
            value={consoleAlternative}
            onChange={(e) => {
              saveSettings({
                consoleAlternative: e.target.value,
                alternativeChangeSource: e.target,
              });
            }}>
      {items}
    </select>
    <div className="AlternativePicker-warning" />
  </div>;
};

export default connect(
  state => merge(
    pick(["consoleAlternative"], state.settings),
      {alternatives: state.alternatives}),
  {saveSettings})(_AlternativePicker);