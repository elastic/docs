import {newStore} from "../../store";
import {saveSettings} from "../../actions/settings";
import AlternativeExamples from "../../components/alternative_examples";

describe(AlternativeExamples, () => {
  let db;
  // This is what the example snippets sort of look like:
  document.head.innerHTML = `
    <style>
      .alternative {
        display: none;
      }
      .AlternativePicker-warning {
        display: none;
      }
    </style>
  `;
  document.body.innerHTML = `
    <div id="guide">
      <div id="csharp-listing"  class="alternative lang-csharp pre_wrapper" />
      <div id="js-listing"      class="alternative lang-js pre_wrapper" />
      <div id="console-listing" class="default lang-console has-csharp has-js pre_wrapper" />
      <div id="widget"          class="has-csharp has-js console_widget">
        <div id="warning"       class="AlternativePicker-warning" />
      </div>
      <div id="csharp-colist"   class="alternative lang-csharp calloutlist" />
      <div id="js-colist"       class="alternative lang-js calloutlist" />
      <div id="console-colist"  class="default lang-console has-csharp has-js calloutlist" />
    </div>
  `;

  const showsLanguage = (selected, warningShown) => {
    // "Weak" but good enough check for visibility.
    const isVisible = element => {
      test("is visible", () => {
        expect(window.getComputedStyle(element)).toHaveProperty("display", "block");
      });
    };
    const isHidden = element => {
      test("is hidden", () => {
        expect(window.getComputedStyle(element)).toHaveProperty("display", "none");
      });
    };
    for (let lang of ["csharp", "js", "console"]) {
      describe(`the listing for ${lang}`, () => {
        const listing = document.getElementById(`${lang}-listing`);
        if (lang === selected) {
          isVisible(listing);
        } else {
          isHidden(listing);
        }
      });
      describe(`the colist for ${lang}`, () => {
        const colist = document.getElementById(`${lang}-colist`);
        if (lang === selected) {
          isVisible(colist);
        } else {
          isHidden(colist);
        }
      });
    }
    describe("the widget", () => {
      const widget = document.getElementById("widget");
      isVisible(widget);
    });
    // TODO the warning fails for unknown reasons.....
    // describe("the warning", () => {
    //   const warning = document.getElementById("warning");
    //   if (warningShown) {
    //     isVisible(warning);
    //   } else {
    //     isHidden(warning);
    //   }
    // });
  };

  describe("when initialized with console", () => {
    beforeAll(() => {
      db = newStore({settings: {consoleAlternative: "console"}});
      AlternativeExamples(db);
    });
    afterAll(() => {
      document.getElementById('console-alternative').remove();
    });

    showsLanguage("console", false);

    describe("changed to csharp", () => {
      beforeAll(() => {
        db.dispatch(saveSettings({consoleAlternative: "csharp"}));
      });
      showsLanguage("csharp", false);
      describe("then changed to js", () => {
        beforeAll(() => {
          db.dispatch(saveSettings({consoleAlternative: "js"}));
        });
        showsLanguage("js", false);
        describe("then changed to bogus", () => {
          beforeAll(() => {
            db.dispatch(saveSettings({consoleAlternative: "bogus"}));
          });
          showsLanguage("console", true);
        });
      });
    });
  });

  describe("when initialized with csharp", () => {
    beforeAll(() => {
      db = newStore({settings: {consoleAlternative: "csharp"}});
      AlternativeExamples(db);
    });
    afterAll(() => {
      document.getElementById('console-alternative').remove();
    });

    showsLanguage("csharp", false);
  });

  describe("when initialized with bogus", () => {
    beforeAll(() => {
      db = newStore({settings: {consoleAlternative: "bogus"}});
      AlternativeExamples(db);
    });
    afterAll(() => {
      document.getElementById('console-alternative').remove();
    });

    showsLanguage("console", true);
  });
});
