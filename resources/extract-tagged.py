#!/usr/bin/env python

# Extract a tagged portion of a file.

def extract_tagged(target, tag):
    import re
    start = re.compile('^(\s+).+tag::' + tag + '\s*\n')
    end = re.compile('end::' + tag + '\s*\n')
    foundTag = False

    result = ''
    with open(target, 'r') as f:
        for line in f:
            if end.search(line):
                return result
            if foundTag:
                result = result + line.replace(indentation, '', 1)
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
