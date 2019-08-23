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

    /* Since this swaps a lot of `display: none` with `display: block` we can
     * expect it to force a reflow which feels like a "jump" when you are
     * looking at the page. We attempt to prevent the "jump" by keeping the
     * element that initiated the state change in the same position on
     * the page. */
    const changeSource = store.getState().settings.alternativeChangeSource;
    const beforeTop = changeSource ? changeSource.getBoundingClientRect().top : 0;
    // Clear all the rules because they were for showing a different alternative
    for (let i = sheet.cssRules.length - 1; i >= 0; i--) {
      sheet.deleteRule(i);
    }
    // The default doesn't need any rules.
    if (newValue !== "console") {
      /* Setup rules to show alternatives when they exist and keep the default
      * when there isn't an alternative. */
      sheet.insertRule(`#guide .default.has-${newValue} { display: none; }`);
      sheet.insertRule(`#guide .alternative.lang-${newValue} { display: block; }`);
      // Setup rules to show the warning unless the snippet has that alternative
      sheet.insertRule(`#guide .AlternativePicker-warning { display: block; }`);
      sheet.insertRule(`#guide .has-${newValue} .AlternativePicker-warning { display: none; }`);
      // TODO check if it is faster to remove the sheet, add the rules, and re-add the sheet.
    }
    const afterTop = changeSource ? changeSource.getBoundingClientRect().top : 0;
    window.scrollBy(0, afterTop - beforeTop);
  };
  updateSheet();
  store.subscribe(updateSheet);
};
