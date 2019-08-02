import {h} from "../../../../../node_modules/preact";
import {connect} from "../../../../../node_modules/preact-redux";
import {closeModal} from "../actions/modal";

export const Modal = props => {
  return props.isOpen && (
    <div id="settings_modal_bg">
      <div id="settings_modal">
        <div className="settings_modal-close" onClick={props.closeModal}>&times;</div>
        {props.children}
      </div>
    </div>
  );
};

export default connect(state => ({
  isOpen: state.modal.isOpen
}), {closeModal})(Modal);
