import {h} from "preact";
import {connect} from "preact-redux";
import {newStore} from "../../store";
import {mount} from "../../components/mount";
import {describe} from "yargs";

const Component = connect(state => ({
  msg: state.settings.msg
}))(props => <h1>{props.msg}</h1>);

describe("Mount component", () => {
  let div;
  beforeAll(() => {
    div = document.createElement('div');
  });

  afterEach(() => {
    div.innerHTML = '';
  });

  test("Wraps the component in a store provider", () => {
    const db = newStore({settings: {msg: "Hello"}});
    mount({el: div, Component, store: db});
    const el = div.querySelector("h1").innerHTML;
    expect(el).toBe("Hello");
  });
});
