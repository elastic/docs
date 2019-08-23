import {curry} from "../../../../../node_modules/ramda";

/*
 * Widget to switch the displayed alternative langauge when the configured
 * language switches.
 */

/* Since this swaps a lot of `display: none` with `display: block` we can
 * expect it to force a reflow which feels like a "jump" when you are
 * looking at the page. We attempt to prevent the "jump" by keeping the
 * element that initiated the state change in the same position on
 * the page. */
const preScrollToKeepOnScreen = (element) => {
  /*
   * NOTE: This isn't tested in jest and needs to be verified visually
   *       if modified!!!!!1111one
   */
  if (!element) {
    return () => {};
  }
  const beforeTop = element.getBoundingClientRect().top;
  return () => {
    const afterTop = element.getBoundingClientRect().top;
    window.scrollBy(0, afterTop - beforeTop);
  }
};

export const _AlternativeSwitcher = (preScrollToKeepOnScreen, store) => {
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

    const scroll = preScrollToKeepOnScreen(store.getState().settings.alternativeChangeSource);
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
      sheet.insertRule(`#guide .AlternativePicker-warning { visibility: visible; }`);
      sheet.insertRule(`#guide .has-${newValue} .AlternativePicker-warning { visibility: hidden; }`);
      // TODO check if it is faster to remove the sheet, add the rules, and re-add the sheet.
    }
    scroll();
  };
  updateSheet();
  store.subscribe(updateSheet);
};

export default curry(_AlternativeSwitcher)(preScrollToKeepOnScreen);
