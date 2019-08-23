import {newStore} from "../../store";
import {saveSettings} from "../../actions/settings";
import {_AlternativeSwitcher} from "../../components/alternative_switcher";

describe(_AlternativeSwitcher, () => {
  let db;
  document.head.innerHTML = `
    <style>
      /* Mimic the main css so the tests detect "display" correctly. */
      .alternative {
        display: none;
      }
      .AlternativePicker-warning {
        display: none;
      }
      </style>
  `;
  // This is what the example snippets sort of look like:
  document.body.innerHTML = `
    <div id="guide">
      <div id="csharp-listing"  class="alternative lang-csharp pre_wrapper"></div>
      <div id="js-listing"      class="alternative lang-js pre_wrapper"></div>
      <div id="console-listing" class="default lang-console has-csharp has-js pre_wrapper"></div>
      <div id="widget"          class="has-csharp has-js console_widget">
        <div id="picker"></div>
        <div id="warning"       class="AlternativePicker-warning"></div>
      </div>
      <div id="csharp-colist"   class="alternative lang-csharp calloutlist"</div>
      <div id="js-colist"       class="alternative lang-js calloutlist"></div>
      <div id="console-colist"  class="default lang-console has-csharp has-js calloutlist"></div>
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

  const noScrolling = (element) => {
    expect(element).toBeUndefined();
    return () => {};
  }

  describe("when initialized with console", () => {
    const picker = document.getElementById("picker");
    const scrolls = [];
    const scrollChecker = (element) => {
      scrolls.push("before");
      scrolls.push(element);
      return () => {
        scrolls.push("after");
      };
    }
    beforeAll(() => {
      db = newStore({settings: {consoleAlternative: "console"}});
      _AlternativeSwitcher(scrollChecker, db);
    });
    afterAll(() => {
      document.getElementById('console-alternative').remove();
    });

    showsLanguage("console", false);
    test("hasn't scrolled", () => {
      expect(scrolls).toEqual(["before", undefined, "after"]);
    });

    describe("changed to csharp", () => {
      beforeAll(() => {
        db.dispatch(saveSettings({
          consoleAlternative: "csharp",
          alternativeChangeSource: picker,
        }));
      });
      showsLanguage("csharp", false);
      test("scrolls after selecting", () => {
        expect(scrolls).toEqual([
          "before", undefined, "after",
          "before", picker, "after",
        ]);
      });
      describe("then changed to js", () => {
        beforeAll(() => {
          db.dispatch(saveSettings({
            consoleAlternative: "js",
            alternativeChangeSource: picker,
          }));
        });
        showsLanguage("js", false);
        test("scrolls after selecting", () => {
          expect(scrolls).toEqual([
            "before", undefined, "after",
            "before", picker, "after",
            "before", picker, "after",
          ]);
        });  
        describe("then changed to bogus", () => {
          beforeAll(() => {
            db.dispatch(saveSettings({
              consoleAlternative: "bogus",
              alternativeChangeSource: picker,
            }));
          });
          showsLanguage("console", true);
          test("scrolls after selecting", () => {
            expect(scrolls).toEqual([
              "before", undefined, "after",
              "before", picker, "after",
              "before", picker, "after",
              "before", picker, "after",
            ]);
          });
          describe("then changed to console", () => {
            beforeAll(() => {
              db.dispatch(saveSettings({
                consoleAlternative: "console",
                alternativeChangeSource: picker,
              }));
            });
            showsLanguage("console", false);
            test("scrolls after selecting", () => {
              expect(scrolls).toEqual([
                "before", undefined, "after",
                "before", picker, "after",
                "before", picker, "after",
                "before", picker, "after",
                "before", picker, "after",
              ]);
            });
            describe("then kept at console but still firing a change event", () => {
              beforeAll(() => {
                db.dispatch(saveSettings({
                  consoleAlternative: "console",
                  alternativeChangeSource: picker,
                }));
              });
              showsLanguage("console", false);
              test("doesn't scroll", () => {
                expect(scrolls).toEqual([
                  "before", undefined, "after",
                  "before", picker, "after",
                  "before", picker, "after",
                  "before", picker, "after",
                  "before", picker, "after",
                ]);
              });
            });
          });
        });
      });
    });
  });

  describe("when initialized with csharp", () => {
    beforeAll(() => {
      db = newStore({settings: {consoleAlternative: "csharp"}});
      _AlternativeSwitcher(noScrolling, db);
    });
    afterAll(() => {
      document.getElementById('console-alternative').remove();
    });

    showsLanguage("csharp", false);
  });

  describe("when initialized with bogus", () => {
    beforeAll(() => {
      db = newStore({settings: {consoleAlternative: "bogus"}});
      _AlternativeSwitcher(noScrolling, db);
    });
    afterAll(() => {
      document.getElementById('console-alternative').remove();
    });

    showsLanguage("console", true);
  });
});
