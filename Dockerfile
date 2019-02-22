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
#   * python (is python2)
#   * xsltproc
# * To install rubygems for asciidoctor
#   * build-essential
#   * cmake
#   * libxml2-dev
#   * make
#   * ruby
#   * ruby-dev
# * Used to check the docs build in CI
#   * python3
#   * python3-pip
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
  python3 \
  python3-pip \
  ruby \
  ruby-dev \
  unzip \
  xsltproc

# We mount these directories with tmpfs so we can write to them so they
# have to be empty. So we delete them.
RUN rm -rf /var/log/nginx && rm -rf /run

# Gem inventory:
# * Used by the docs build
#   * asciidoctor
#   * thread_safe
# * Speculative
#   * asciidoctor-diagram
#   * asciimath
# * Used to check the build in CI
#   * rubocop
#   * rspec
RUN gem install --no-document \
  asciidoctor:1.5.8 \
  asciidoctor-diagram:1.5.12 \
  asciimath:1.0.8 \
  rubocop:0.64.0 \
  rspec:3.8.0 \
  thread_safe:0.3.6

# Wheel inventory:
# * Used to test the docs build
#   * beautifulsoup4
#   * lxml
#   * pycodestyle
RUN pip3 install \
  beautifulsoup4==4.7.1 \
  lxml==4.3.1 \
  pycodestyle==2.5.0
