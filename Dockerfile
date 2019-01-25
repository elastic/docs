# The asciidoctor docker image doesn't really have versions so we build
# directly on Alpine and install asciidoctor ourselves so we can pin its
# version.
FROM alpine:3.7

LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"

# Used by the docs build or asciidoctor
RUN apk add --no-cache \
bash \
curl \
git \
libxml2-utils \
libxslt \
make \
nginx \
openssh-client \
perl \
python2 \
ruby \
ruby-mathematical \
unzip \
which

# Install asciidoctor, but don't keep the -devel deps around
RUN apk add --no-cache --virtual .rubymakedepends \
build-base \
libxml2-dev \
ruby-dev \
&& gem install --no-document \
asciidoctor:1.5.8 \
asciidoctor-diagram:1.5.12 \
asciidoctor-mathematical:0.2.2 \
asciimath:1.0.8 \
thread_safe:0.3.6 \
&& apk del -r --no-cache .rubymakedepends
