#!/usr/bin/env python

# Extract a tagged portion of a file.

def extract_tagged(target, tag):
    import re
    start = re.compile('^(\s+).+tag::' + tag)
    end = re.compile('end::' + tag)
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
    from sys import argv, stdout
    result = extract_tagged(argv[1], argv[2])
    if result:
        stdout.write(result)
    else:
        print("Couldn't find " + tag)
        exit(1)
