#!/usr/bin/env python

# Extract a tagged portion of a file.

def extract_tagged(target, tag):
    import re
    start = re.compile('^(\s+).+tag::' + tag)
    end = re.compile('end::' + tag)
    callout = re.compile(r'// (<[^>]+>)\s*?\n')
    foundTag = False

    result = ''
    with open(target, 'r') as f:
        for line in f:
            if end.search(line):
                return result
            if foundTag:
                line = line.replace(indentation, '', 1)
                line = callout.sub(r'\1\n', line)
                result = result + line
            else:
                m = start.search(line)
                if m:
                    foundTag = True
                    indentation = m.group(1)


if __name__ == '__main__':
    from sys import argv, stdout, stderr
    try:
        result = extract_tagged(argv[1], argv[2])
        if result:
            stdout.write(result)
        else:
            raise Exception("Couldn't find tag")
    except Exception as e:
      stderr.write("asciidoc: ERROR: Extracting tag `" + argv[2] + "` from file `" + argv[1]+ "`: " + e.__str__() + "\n")
      exit(1)
