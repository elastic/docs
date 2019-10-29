# Debian builds the docs about 20% faster than alpine. The image is larger
# and takes longer to build but that is worth it.
FROM bitnami/minideb:buster

LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"

# Setup repos for things like node and yarn
RUN install_packages apt-transport-https gnupg2 ca-certificates
COPY .docker/apt/sources.list.d/* /etc/apt/sources.list.d/
COPY .docker/apt/keys/* /
RUN cat /nodesource.gpg | apt-key add - && rm /nodesource.gpg
RUN cat /yarn.gpg | apt-key add - && rm yarn.gpg

# Package inventory:
# * To make life easier
#   * bash
#   * less
# * Used by the docs build
#   * libnss-wrapper
#   * libxml-libxml-perl
#   * libxml2-utils
#   * nginx
#   * openssh-client (used by git)
#   * openssh-server (used to forward ssh auth for git when running with --all on macOS)
#   * perl-base
#   * python (is python2)
#   * xsltproc
# * To install rubygems for asciidoctor
#   * bundler
#   * build-essential
#   * cmake
#   * libxml2-dev
#   * make
#   * ruby
#   * ruby-dev
# * Used to check the docs build in CI
#   * python3
#   * python3-pip
# * Used to check javascript
#   * nodejs
#   * yarn
RUN install_packages \
  bash \
  build-essential \
  bundler \
  curl \
  cmake \
  git \
  less \
  libnss-wrapper \
  libxml-libxml-perl \
  libxml2-dev \
  libxml2-utils \
  make \
  nodejs \
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
  yarn \
  xsltproc

# We mount these directories with tmpfs so we can write to them so they
# have to be empty. So we delete them.
RUN rm -rf /var/log/nginx && rm -rf /run/nginx

# Wheel inventory:
# * Used to test the docs build
#   * beautifulsoup4
#   * lxml
#   * pycodestyle
RUN pip3 install \
  beautifulsoup4==4.7.1 \
  lxml==4.3.1 \
  pycodestyle==2.5.0

# Install ruby deps with bundler to make things more standard for Ruby folks.
RUN bundle config --global silence_root_warning 1
COPY Gemfile* /
RUN bundle install --binstubs --system --frozen
COPY .docker/asciidoctor_2_0_10.patch /
RUN cd /var/lib/gems/2.5.0/gems/asciidoctor-2.0.10 && patch -p1 < /asciidoctor_2_0_10.patch
# --frozen forces us to regenerate Gemfile.lock locally before using it in
# docker which is important because we need Gemfile.lock to lock the gems to a
# consistent version and we can't rely on running bundler in docker to update
# it because we can't copy from the image to the host machine while building
# the image.

COPY package.json /
COPY yarn.lock /
ENV YARN_CACHE_FOLDER=/tmp/.yarn-cache
RUN yarn install --frozen-lockfile
