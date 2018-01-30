#!/bin/bash

BASEDIR=$(dirname $0)

FILE="fo_titlepage"
echo "Generating $FILE.xsl"
xsltproc --output $BASEDIR/$FILE.xsl $BASEDIR/docbook-xsl-1.78.1/template/titlepage.xsl $BASEDIR/${FILE}_template.xml
