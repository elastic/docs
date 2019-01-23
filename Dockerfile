# The asciidoctor docker image doesn't really have versions so we build
# directly on Alpine and install asciidoctor ourselves so we can pin its
# version.

FROM alpine:3.7

LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"

ENV ASCIIDOCTOR_VERSION=1.5.8

# NOCOMMIT trim these
# NOCOMMIT add rspec for easy testing

# Used by asciidoctor or its installation
RUN apk add --no-cache \
bash \
curl \
make \
py2-pillow \
py-setuptools \
python2 \
ruby \
ruby-mathematical \
ttf-liberation \
unzip \
which

# Install asciidoctor, but don't keep the ruby-devel deps around
RUN apk add --no-cache --virtual .rubymakedepends \
build-base \
libxml2-dev \
ruby-dev \
&& gem install --no-document \
"asciidoctor:${ASCIIDOCTOR_VERSION}" \
asciidoctor-diagram \
asciidoctor-mathematical \
asciimath \
haml \
kindlegen:3.0.3 \
rake \
rouge \
slim \
thread_safe \
tilt \
&& apk del -r --no-cache .rubymakedepends

# Used by the Elasticsearch docs build
RUN apk add --no-cache \
perl \
git \
libxslt \
libxml2-utils \
nginx
