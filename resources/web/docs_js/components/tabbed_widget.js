export const switchTabs = () => {
  document.addEventListener("DOMContentLoaded", () => {
    const tabs = document.querySelectorAll('[role="tab"]');
    const tabList = document.querySelector('[role="tablist"]');
    // Add a click event handler to each tab
    tabs.forEach(tab => {
      tab.addEventListener("click", changeTabs);
    });
    // Enable arrow navigation between tabs in the tab list
    let tabFocus = 0;
    if (tabList) {
      tabList.addEventListener("keydown", e => {
        // Move right
        if (e.keyCode === 39 || e.keyCode === 37) {
          tabs[tabFocus].setAttribute("tabindex", -1);
          if (e.keyCode === 39) {
            tabFocus++;
            // If we're at the end, go to the start
            if (tabFocus >= tabs.length) {
              tabFocus = 0;
            }
            // Move left
          } else if (e.keyCode === 37) {
            tabFocus--;
            // If we're at the start, move to the end
            if (tabFocus < 0) {
              tabFocus = tabs.length - 1;
            }
          }
          tabs[tabFocus].setAttribute("tabindex", 0);
          tabs[tabFocus].focus();
        }
      });
    }
  });
}

const setActiveTab = (target) => {
  const parent = target.parentNode;
  const grandparent = parent.parentNode;
  // Remove all current selected tabs
  parent
    .querySelectorAll('[aria-selected="true"]')
    .forEach(t => t.setAttribute("aria-selected", false));
  // Set this tab as selected
  target.setAttribute("aria-selected", true);
  // Hide all tab panels
  grandparent
    .querySelectorAll('[role="tabpanel"]')
    .forEach(p => p.setAttribute("hidden", true));
  // Show the selected panel
  grandparent.parentNode
    .querySelector(`#${target.getAttribute("aria-controls")}`)
    .removeAttribute("hidden");
}

const changeTabs = (e) => {
  // get the containing list of the tab that was just clicked
  const tabList = e.target.parentNode;

  // get all of the sibling tabs
  const buttons = Array.apply(null, tabList.querySelectorAll('button'));

  // loop over the siblings to discover which index thje clicked one was
  const { index } = buttons.reduce(({ found, index }, button) => {
    if (!found && buttons[index] === e.target) {
      return { found: true, index };
    } else if (!found) {
      return { found, index: index + 1 };
    } else {
      return { found, index };
    }
  }, { found: false, index: 0 });

  // get the tab container
  const container = tabList.parentNode;
  // read the data-tab-group value from the container, e.g. "os"
  const { tabGroup } = container.dataset;
  // get a list of all the tab groups that match this value on the page
  const groups = document.querySelectorAll('[data-tab-group=' + tabGroup + ']');

  // for each of the found tab groups, find the tab button at the previously discovered index and select it for each group
  groups.forEach((group) => {
    const target = group.querySelectorAll('button')[index];
    setActiveTab(target);
  });
}
