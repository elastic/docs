/*
 * Widget to switch the displayed alternative langauge when the configured
 * language switches.
 */

export default store => {
  const style = document.createElement('style');
  style.id = 'console-alternative';
  document.head.appendChild(style);
  const sheet = style.sheet;

  let oldValue = null;

  const updateSheet = () => {
    const newValue = store.getState().settings.consoleAlternative;
    if (oldValue === newValue) {
      return;
    }
    oldValue = newValue;

    // Clear all the rules because they were for showing a different alternative
    for (let i = sheet.cssRules.length - 1; i >= 0; i--) {
      sheet.deleteRule(i);
    }
    // The default doesn't need any rules.
    if (newValue === "console") {
      return;
    }

    /* Setup rules to show alternatives when they exist and keep the default
     * when there isn't an alternative. */
    sheet.insertRule(`#guide .default.has-${newValue} { display: none; }`);
    sheet.insertRule(`#guide .alternative.lang-${newValue} { display: block; }`);
    // Setup rules to show the warning unless the snippet has that alternative
    sheet.insertRule(`#guide .AlternativePicker-warning { visibility: visible; }`);
    sheet.insertRule(`#guide .has-${newValue} .AlternativePicker-warning { visibility: hidden; }`);
  };
  updateSheet();
  store.subscribe(updateSheet);
};
