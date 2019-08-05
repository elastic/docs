import {dissoc} from "../../../../../node_modules/ramda";

const initialState = {isOpen: false, Component: null, props: null};

const SET_MODAL = "SET_MODAL_VALUE";

export const setModal   = ({isOpen, Component, props}) => ({type: SET_MODAL, isOpen, Component, props});
export const openModal  = (Component, props) => setModal({isOpen: true, Component, props});
export const closeModal = () => setModal({isOpen: false});

export const reducer = (state = initialState, action) => {
  switch (action.type) {
    case SET_MODAL:
      return action.isOpen ? dissoc("type", action) : initialState;
    default:
      return state;
  }
};
