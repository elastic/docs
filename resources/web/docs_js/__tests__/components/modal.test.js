import {newStore} from "../../store";
import {mount} from "../../components/mount";
import Modal from "../../components/modal";

describe("Modal component", () => {
  let div;
  beforeAll(() => {
    div = document.createElement('div');
  });

  afterEach(() => {
    div.innerHTML = '';
  });

  test("it's hidden when modal.isOpen is false", () => {
    const db = newStore({modal: {isOpen: false}});
    mount({el: div, Component: Modal, store: db});
    const el = div.querySelector("#settings_modal_bg");
    expect(el).toBe(null);
  });

  test("it's shown when modal.isOpen is true", () => {
    const db = newStore({modal: {isOpen: true}});
    mount({el: div, Component: Modal, store: db});
    const el = div.querySelector("#settings_modal_bg");

    expect(el).not.toBeNull();
  });

  test("Clicking close, closes the modal", () => {
    const db = newStore({modal: {isOpen: true}});
    mount({el: div, Component: Modal, store: db});
    const el = div.querySelector(".settings_modal-close");

    el.click();

    setTimeout(() => {
      const final = div.querySelector("#settings_modal_bg");
      expect(final).toBe(null);
    }, 1);
  });
});
