# Debian builds the docs about 20% faster than alpine. The image is larger
# and takes longer to build but that is worth it.
FROM bitnami/minideb:stretch

LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"

# Package inventory:
# * To make life easier
#   * bash
# * Used by the docs build
#   * libnss-wrapper
#   * libxml2-utils
#   * nginx
#   * openssh-client (used by git)
#   * openssh-server (used to forward ssh auth for git when running with --all on macOS)
#   * perl-base
#   * xsltproc
# * To install rubygems for asciidoctor
#   * build-essential
#   * cmake
#   * libxml2-dev
#   * make
#   * ruby
#   * ruby-dev
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
  openssh-server \
  perl-base \
  python \
  ruby \
  ruby-dev \
  unzip \
  xsltproc

# We mount these directories with tmpfs so we can write to them while so they
# have to be empty.
RUN rm -rf /var/log/nginx && rm -rf /run

RUN gem install --no-document \
  asciidoctor:1.5.8 \
  asciidoctor-diagram:1.5.12 \
  asciimath:1.0.8 \
  thread_safe:0.3.6
