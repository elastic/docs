import { h, Component } from '../../../../../../node_modules/preact';

export default class FeedbackWidget extends Component {
  render() {
    return (
      <div>
        <div id="feedbackWidget">
          Was this helpful?
          <span className="docHorizontalSpacer"></span>
          <fieldset className="buttonGroup">
            <legend className="screenReaderOnly">Feedback</legend>
            <div className="buttonGroup">
              <button
                aria-pressed="false"
                id="feedbackLiked"
                type="button"
                className="feedbackButton feedbackLiked"
                title="Like"
              >
                <span className="feedbackButtonContent">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    className="feedbackIcon unpressed"
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
                    className="feedbackIcon pressed"
                    role="img"
                    data-is-loaded="true"
                    aria-hidden="true"
                  >
                    <path d="M1 21h4V9H1v12zm22-11c0-1.1-.9-2-2-2h-6.31l.95-4.57l.03-.32c0-.41-.17-.79-.44-1.06L14.17 1L7.59 7.59C7.22 7.95 7 8.45 7 9v10c0 1.1.9 2 2 2h9c.83 0 1.54-.5 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2z"></path>
                  </svg>
                  <span className="screenReaderOnly" data-text="Like">
                    Like
                  </span>
                </span>
              </button>
              <button
                aria-pressed="false"
                id="feedbackDisliked"
                type="button"
                className="feedbackButton feedbackDisliked"
                title="Dislike"
              >
                <span className="feedbackButtonContent">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    className="feedbackIcon unpressed"
                    role="img"
                    aria-hidden="true"
                  >
                    <path d="M15 3H6c-.83 0-1.54.5-1.84 1.22l-3.02 7.05c-.09.23-.14.47-.14.73v2c0 1.1.9 2 2 2h6.31l-.95 4.57l-.03.32c0 .41.17.79.44 1.06L9.83 23l6.59-6.59c.36-.36.58-.86.58-1.41V5c0-1.1-.9-2-2-2zm0 12l-4.34 4.34L12 14H3v-2l3-7h9v10zm4-12h4v12h-4z"></path>
                  </svg>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    className="feedbackIcon pressed"
                    role="img"
                    data-is-loaded="true"
                    aria-hidden="true"
                  >
                    <path d="M15 3H6c-.83 0-1.54.5-1.84 1.22l-3.02 7.05c-.09.23-.14.47-.14.73v2c0 1.1.9 2 2 2h6.31l-.95 4.57l-.03.32c0 .41.17.79.44 1.06L9.83 23l6.59-6.59c.36-.36.58-.86.58-1.41V5c0-1.1-.9-2-2-2zm4 0v12h4V3h-4z"></path>
                  </svg>
                  <span className="screenReaderOnly" data-text="Dislike">
                    Dislike
                  </span>
                </span>
              </button>
            </div>
          </fieldset>
        </div>
        <div id="feedbackSuccess" className="hidden">
          Thank you for your feedback.
        </div>
      </div>
    );
  }
}
