import {h} from "../../../../../node_modules/preact";
import {connect} from "../../../../../node_modules/preact-redux";
import {closeModal} from "../actions/modal";

export const Modal = ({Component, props, isOpen, closeModal}) => {
  return isOpen && (
    <div id="settings_modal_bg">
      <div id="settings_modal">
        <div className="settings_modal-close" onClick={closeModal}>&times;</div>
        <Component {...props} />
      </div>
    </div>
  );
};

export default connect(state => ({
  ...state.modal
}), {closeModal})(Modal);
