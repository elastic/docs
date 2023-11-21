import { h, Component } from '../../../../../../node_modules/preact';

const FEEDBACK_URL = 'https://docs.elastic.co/api/feedback'
const MAX_COMMENT_LENGTH = 1000;

export default class FeedbackModal extends Component {
  constructor(props) {
    super(props);
    this.state = {
      comment: '',
      modalClosed: false,
      isLoading: false,
      hasError: false,
    };
    this.onEscape = this.onEscape.bind(this);
    this.resetState = this.resetState.bind(this);
    this.submitFeedback = this.submitFeedback.bind(this);
  }

  onEscape(event) {
    if (event.key === 'Escape') {
      this.resetState();
    }
  }

  resetState() {
    this.setState({ modalClosed: true });
    document.querySelectorAll('.isPressed').forEach((el) => {
      el.classList.remove('isPressed');
    });
  }

  submitFeedback() {
    this.setState({ isLoading: true });
    fetch(FEEDBACK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        comment: this.state.comment,
        feedback: this.props.isLiked ? 'liked' : 'disliked',
      }),
    })
      .then((response) => response.json())
      .then(() => {
        this.setState({ modalClosed: true })
        document.getElementById('feedbackSuccess').classList.remove('hidden')
        document.querySelectorAll('.feedbackButton').forEach((el) => {
          el.disabled = true
        })
      })
      .catch((error) => {
        this.setState({ isLoading: false, hasError: true });
        console.error('Error:', error);
      });

  }

  componentDidMount() {
    document.addEventListener('keydown', this.onEscape, false);
  }

  componentWillUnmount() {
    document.removeEventListener('keydown', this.onEscape, false);
  }

  render(props, state) {
    const { isLiked } = props;
    const { modalClosed, isLoading, hasError, comment } = state;
    const maxCommentLengthReached = comment.length > MAX_COMMENT_LENGTH;
    const sendDisabled = isLoading || maxCommentLengthReached;

    if (modalClosed) {
      return null;
    }

    return (
      <div
        data-relative-to-header="above"
        id="feedbackModal"
      >
        <div
          data-focus-guard="true"
          tabindex="0"
          style="width: 1px; height: 0px; padding: 0px; overflow: hidden; position: fixed; top: 1px; left: 1px;"
        ></div>
        <div data-focus-lock-disabled="false">
          <div className="feedbackModalContent" tabindex="0">
            <button
              className="closeIcon"
              type="button"
              aria-label="Closes this modal window"
              onClick={this.resetState}
              disabled={isLoading}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 16 16"
                role="img"
                data-icon-type="cross"
                data-is-loaded="true"
                aria-hidden="true"
              >
                <path d="M7.293 8 3.146 3.854a.5.5 0 1 1 .708-.708L8 7.293l4.146-4.147a.5.5 0 0 1 .708.708L8.707 8l4.147 4.146a.5.5 0 0 1-.708.708L8 8.707l-4.146 4.147a.5.5 0 0 1-.708-.708L7.293 8Z"></path>
              </svg>
            </button>
            <div className="feedbackModalHeader">
              <h2>Send us your feedback</h2>
            </div>
            <div className="feedbackModalBody">
              <div className="feedbackModalBodyOverflow">
                <div>
                  Thank you for helping us improve Elastic documentation.
                </div>
                <div className="spacer"></div>
                <div className="feedbackForm">
                  <div className="feedbackFormRow">
                    <div className="feedbackFormRow__labelWrapper">
                      <label
                        className="feedbackFormLabel"
                        id="feedbackLabel"
                        for="feedbackComment"
                      >
                        Additional comment (optional)
                      </label>
                    </div>
                    <div className="feedbackFormRow__fieldWrapper">
                      <div className="feedbackFormControlLayout">
                        <div className="feedbackFormControlLayout__childrenWrapper">
                          <textarea
                            className="feedbackTextArea"
                            rows="6"
                            id="feedbackComment"
                            disabled={isLoading}
                            onKeyUp={(e) =>
                              this.setState({ comment: e.target.value })
                            }
                          ></textarea>
                          {maxCommentLengthReached && (
                            <div className="feedbackFormError">
                              Max comment length of {MAX_COMMENT_LENGTH}{' '}
                              characters reached.
                              <br />
                              <br />
                              Character count: {comment.length}
                            </div>
                          )}
                          {hasError && (
                            <div className="feedbackFormError">
                              There was a problem submitting your feedback.
                              <br />
                              <br />
                              Please try again.
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div
              className={`feedbackModalFooter ${isLoading ? 'loading' : ''}`}
            >
              <button
                className="feedbackButton cancelButton"
                type="button"
                onClick={this.resetState}
                disabled={isLoading}
              >
                <span className="feedbackButtonContent">
                  <span>Cancel</span>
                </span>
              </button>
              <button
                type="button"
                disabled={sendDisabled}
                className={`feedbackButton sendButton ${
                  isLiked ? 'like' : 'dislike'
                }`}
                onClick={this.submitFeedback}
              >
                <span className="loadingContent">
                  <span
                    class="loadingSpinner"
                    role="progressbar"
                    aria-label="Loading"
                    style="border-color: rgb(0, 119, 204) currentcolor currentcolor;"
                  ></span>
                  <span>Sending...</span>
                </span>
                <span className="feedbackButtonContent">
                  <span>Send</span>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    className="sendIcon like"
                    role="img"
                    aria-hidden="true"
                  >
                    <path d="M9 21h9c.83 0 1.54-.5 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2c0-1.1-.9-2-2-2h-6.31l.95-4.57l.03-.32c0-.41-.17-.79-.44-1.06L14.17 1L7.58 7.59C7.22 7.95 7 8.45 7 9v10c0 1.1.9 2 2 2zM9 9l4.34-4.34L12 10h9v2l-3 7H9V9zM1 9h4v12H1z"></path>
                  </svg>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    className="sendIcon dislike"
                    role="img"
                    aria-hidden="true"
                  >
                    <path d="M15 3H6c-.83 0-1.54.5-1.84 1.22l-3.02 7.05c-.09.23-.14.47-.14.73v2c0 1.1.9 2 2 2h6.31l-.95 4.57l-.03.32c0 .41.17.79.44 1.06L9.83 23l6.59-6.59c.36-.36.58-.86.58-1.41V5c0-1.1-.9-2-2-2zm0 12l-4.34 4.34L12 14H3v-2l3-7h9v10zm4-12h4v12h-4z"></path>
                  </svg>
                </span>
              </button>
            </div>
          </div>
        </div>
        <div
          data-focus-guard="true"
          tabindex="0"
          style="width: 1px; height: 0px; padding: 0px; overflow: hidden; position: fixed; top: 1px; left: 1px;"
        ></div>
      </div>
    );
  }
}
