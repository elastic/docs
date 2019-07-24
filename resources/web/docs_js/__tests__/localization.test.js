import * as l from "../localization";
import * as R from "../../../../../node_modules/ramda";

describe("Localization of strings", () => {
  const specs = R.toPairs(l.lang_spec);

  R.forEach(([phrase, {zh_cn, en}]) => {
    const expectedEn = en ? en : phrase;

    test(`Correct Chinese translation of the phrase ${phrase}`, () => {
      expect(l.lang_strings("zh_cn")(phrase)).toEqual(zh_cn);
    });

    test(`Correct English translation of the phrase ${phrase}`, () => {
      expect(l.lang_strings("en")(phrase)).toEqual(expectedEn);
    });
  }, specs);

  test("It throws an error for unrecognized phrases", () => {
    expect(() => l.lang_strings("en")("not found")).toThrow(Error);
  });

  test("It throws an error for a language entry for phrase", () => {
    expect(() => l.lang_strings("fr")("Save")).toThrow(Error);
  });
});
