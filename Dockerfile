FROM asciidoctor/docker-asciidoctor
#NOCOMMIT it'd be nice to have a version here

LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"

RUN apk add --no-cache \
perl \
git \
libxslt \
libxml2-utils
