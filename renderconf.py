#!/usr/bin/env python

# Loads and then dumps conf.yaml, to test that changes to the conf.yaml don't lead to actual functional changes in behavior.
# Usage:
#   ./renderconf.py > conf.before.yaml
#   (Make changes)
#   ./renderconf.py > conf.after.yaml
#   diff conf.before.yaml conf.after.yaml

import yaml

yaml.Dumper.ignore_aliases = lambda *args : True


def main():
    data = yaml.load(open("conf.yaml").read(), Loader=yaml.SafeLoader)
    print(yaml.dump(data))

if __name__ == "__main__":
    main()
