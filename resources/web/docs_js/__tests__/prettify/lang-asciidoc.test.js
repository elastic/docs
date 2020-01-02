import PR from "../../../lib/prettify/prettify";
import "../../prettify/lang-asciidoc";
import dedent from "../../../../../../node_modules/dedent";

const prettyAsciidoc = str => PR.prettyPrintOne(str, "asciidoc");
const tag = str => `<span class="tag">${str}</span>`;
const pln = str => `<span class="pln">${str}</span>`;
const com = str => `<span class="com">${str}</span>`;
const str = str => `<span class="str">${str}</span>`;
const kwd = str => `<span class="kwd">${str}</span>`;
const pun = str => `<span class="pun">${str}</span>`;

describe("lang-asciidoc", () => {
  describe("headings", () => {
    const pretty = prettyAsciidoc(dedent `
      = Book title                // level 0

      == Chapter title            // level 1
    `);
    test("the first heading", () => {
      expect(pretty).toContain(tag("=") + pln(" Book title                ") + com("// level 0\n"));
    });
    test("the second heading", () => {
      expect(pretty).toContain(tag("==") + pln(" Chapter title            ") + com("// level 1"));
    });
  });
  test("ids", () => {
    const pretty = prettyAsciidoc(dedent `
      [[intro-to-xyz]]
    `);
    expect(pretty).toContain(tag("[[") + pln("intro-to-xyz") + tag("]]"));
  });
  test("passthrough", () => {
    const pretty = prettyAsciidoc(dedent `
      ++++
      foo
      ++++
    `);
    expect(pretty).toContain(tag("++++") + pln("\nfoo\n") + tag("++++"));
  });
  describe("attribute list", () => {
    test("with the id first", () => {
      const pretty = prettyAsciidoc(dedent `
        [foo,bar=zoo,baz="bort bort"]
      `);
      const id = str("foo") + pun(",");
      const bar = kwd("bar") + pun("=") + str("zoo") + pun(",");
      const baz = kwd("baz") + pun("=") + str(`"bort bort"`);
      expect(pretty).toContain(tag("[") + id + bar + baz + tag("]"));
    });
    test("with an attribute first", () => {
      const pretty = prettyAsciidoc(dedent `
        [bar=zoo]
      `);
      const bar = kwd("bar") + pun("=") + str("zoo");
      expect(pretty).toContain(tag("[") + bar + tag("]"));
    });

  })
});
