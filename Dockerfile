# Debian builds the docs about 20% faster than alpine. The image is larger
# and takes longer to build but that is worth it.
FROM bitnami/minideb:stretch

LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"

# Used by the docs build or asciidoctor
RUN install_packages \
  bash \
  build-essential \
  curl \
  cmake \
  git \
  libnss-wrapper \
  libxml2-dev \
  libxml2-utils \
  make \
  nginx \
  openssh-client \
  perl-base \
  python \
  ruby \
  ruby-dev \
  unzip \
  xsltproc

# We mount this log directory as tmp directory so we can't have
# files there.
RUN rm -rf /var/log/nginx

RUN gem install --no-document \
  asciidoctor:1.5.8 \
  asciidoctor-diagram:1.5.12 \
  asciimath:1.0.8 \
  thread_safe:0.3.6
