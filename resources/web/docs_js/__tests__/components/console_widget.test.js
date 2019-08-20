import {h, render} from "../../../../../../node_modules/preact";
import {ConsoleWidget, AlternativePicker, ConsoleForm} from "../../components/console_widget";

describe(ConsoleWidget, () => {
  let picker;

  beforeAll(() => {
    picker = document.createElement('div');
    document.body.appendChild(picker);
  });

  beforeEach(() => {
    picker.innerHTML = '';
  });

  describe(AlternativePicker, () => {
    describe("when there aren't any alternatives", () => {
      const picker = render(<AlternativePicker />);
      test("is just an empty div", () => {
        expect(picker).toStrictEqual(render(<div/>));
      });
    });
    describe("when there aren't any alternatives", () => {
      const picker = render(<AlternativePicker alternatives={{
        bash: {
          cshell: {},
          emacs: {},
          powershell: {},
        }
      }}/>);
      test("is just an empty div", () => {
        expect(picker).toStrictEqual(render(<div/>));
      });
    });
    describe("when the there are console alternatives", () => {
      const picker = render(<AlternativePicker
        consoleAlternative="console"
        alternatives={{
          console: {
            js: {},
            csharp: {},
          }
        }}/>);
      const select = picker.childNodes[0];
      test("renders all configured options", () => {
        expect(picker).toStrictEqual(render(
          <div class="AlternativePicker u-space-between">
            <select class="AlternativePicker-select">
              <option value="console">Console</option>
              <option value="js">JavaScript</option>
              <option value="csharp">C#</option>
            </select>
            <div class="AlternativePicker-warning" />
          </div>
        ));
      });
      test("selects the consoleAlternative from the props", () => {
        expect(select.value).toBe("console");
      });
    });
    describe("when the the console alternative isn't in the options", () => {
      const picker = render(<AlternativePicker
        consoleAlternative="bort"
        alternatives={{
          console: {
            js: {},
            csharp: {},
          }
        }}/>);
      test("includes an option for the current alternative", () => {
        expect(picker).toStrictEqual(render(
          <div class="AlternativePicker u-space-between">
            <select class="AlternativePicker-select">
              <option value="console">Console</option>
              <option value="js">JavaScript</option>
              <option value="csharp">C#</option>
              <option value="bort">bort</option>
            </select>
            <div class="AlternativePicker-warning" />
          </div>
        ));
      });
    });
    describe("when the value changes", () => {
      const updates = [];
      const picker = render(<AlternativePicker
        consoleAlternative="console"
        saveSettings={s => updates.push(s)}
        alternatives={{
          console: {
            js: {},
            csharp: {},
          }
        }}/>, document.body);
      const select = picker.childNodes[0];
      select.value = 'js';
      /* Browsers don't dispatch a change even when you change the value so we
       * have to do it ourselves. Like an animal. */
      select.dispatchEvent(new Event("change"));
      test("saves the config", () => {
        expect(updates).toStrictEqual([{consoleAlternative: 'js'}]);
      })
    });
  });
});
