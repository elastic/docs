import {h, render} from "../../../../../../node_modules/preact";
import {_AlternativePicker} from "../../components/alternative_picker";

describe(_AlternativePicker, () => {
  describe("when there aren't any alternatives", () => {
    const picker = render(<_AlternativePicker />);
    test("is just an empty div", () => {
      expect(picker).toStrictEqual(render(<div/>));
    });
  });

  describe("when there aren't any alternatives", () => {
    const picker = render(<_AlternativePicker alternatives={{
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

  describe("when there are console alternatives", () => {
    const picker = render(<_AlternativePicker
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
          {null}
        </div>
      ));
    });

    test("selects the consoleAlternative from the props", () => {
      expect(select.value).toBe("console");
    });
  });

  describe("when the console alternative isn't in the options", () => {
    const picker = render(<_AlternativePicker
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
            <option value="bort">Bort</option>
          </select>
          <div class="AlternativePicker-warning" />
          {null}
        </div>
      ));
    });
  });

  describe("when the value changes", () => {
    const updates = [];
    const picker = render(<_AlternativePicker
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
      // We can't use toMatchObject here because tagName is busted.
      expect(updates).toHaveLength(1);
      expect(updates[0].consoleAlternative).toBe("js");
      expect(updates[0].alternativeChangeSource.tagName).toBe("SELECT");
    })
  });
});
