import * as utils from "../utils";

describe("get_base_url", () => {
  test("It leaves the last .html bit off", () => {
    const result = utils.get_base_url("https://localhost:8000/guide/blocks.html");
    expect(result).toEqual("https://localhost:8000/guide/");
  });

  test("It converts http to https", () => {
    const result = utils.get_base_url("http://localhost:8000/a/b/c/d/e/blocks.html");
    expect(result).toEqual("https://localhost:8000/a/b/c/d/e/");
  });
});
