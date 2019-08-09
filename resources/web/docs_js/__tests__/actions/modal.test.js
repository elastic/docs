import * as actions from "../../actions/modal";
import store from "../../store";

describe("Modal actions", () => {
  const db = store();

  test("closed by default", () => {
    expect(db.getState().modal.isOpen).toBe(false);
  });

  test("OpenModal sets isOpen to true", () => {
    db.dispatch(actions.openModal());
    expect(db.getState().modal.isOpen).toEqual(true);
  });

  test("CloseModal sets isOpen to false", () => {
    db.dispatch(actions.closeModal());
    expect(db.getState().modal.isOpen).toEqual(false);
  });
});
