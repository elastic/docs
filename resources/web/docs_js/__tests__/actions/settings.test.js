import Cookies from "../../../../../../node_modules/js-cookie";
import * as actions from "../../actions/settings";
import store from "../../store";

describe("saveSettings", () => {
  const db = store({modal: {isOpen: true}});

  test("the modal is open", () => {
    expect(db.getState().modal.isOpen).toBe(true);
  });

  test("it converts a map to list of tuples", () => {
    const setCookies = jest.fn();
    const saveSettings = actions._saveSettings(setCookies);
    db.dispatch(saveSettings({
      console_url: "c",
      language: "en"
    }));

    expect(setCookies).toHaveBeenCalledWith([["console_url", "c"], ["language", "en"]]);
  });

  test("it updates the store", () => {
    const settings = db.getState().settings;
    expect(settings).toEqual({
      console_url: "c",
      language: "en"
    });
  });

  test("it closes the modal", () => {
    expect(db.getState().modal.isOpen).toBe(false);
  });
});

describe("setCookies", () => {
  test("it iterates and saves cookies", () => {
    actions.setCookies([["a", "b"], ["c", "d"]]);

    expect(Cookies.get("a")).toBe("b");
    expect(Cookies.get("c")).toBe("d");
  });
});
