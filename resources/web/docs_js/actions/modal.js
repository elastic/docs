const SET_MODAL = "SET_MODAL_VALUE";

export const setModal   = val => ({type: SET_MODAL, value: val});
export const openModal  = setModal.bind(null, true);
export const closeModal = setModal.bind(null, false);

const initialState = {isOpen: false};

export const reducer = (state = initialState, action) => {
  switch (action.type) {
    case SET_MODAL:
      return {isOpen: action.value};
    default:
      return state;
  }
};
