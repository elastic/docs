# This builds a "base" image that contains dependencies that are required at
# runtime *and* to install dependencies like `ruby`. Then it builds images that
# intall those dependencies. Then it builds a "final" image that copies the
# dependencies and installs package that it needs at runtime. Compared to
# installing everything in one go this shrinks the "final" docker image by
# about 50%, mostly because we don't need things like `gcc` and `ruby-dev` in
# the "final" image.

# Debian builds the docs about 20% faster than alpine. The image is larger
# and takes longer to build but that is worth it.
FROM bitnami/minideb:buster AS base

# TODO install_packages calls apt-get update and then nukes the list files after. We should avoid multiple calls to apt-get update.....

# Setup the repo for node
RUN install_packages apt-transport-https gnupg2 ca-certificates
COPY .docker/apt/keys/nodesource.gpg /
RUN apt-key add /nodesource.gpg
COPY .docker/apt/sources.list.d/nodesource.list /etc/apt/sources.list.d/
RUN install_packages \
  nodejs python3 ruby \
    # Used both to install dependencies and at run time
  bash less
    # Just in case you have to shell into the image


FROM base as py_deps
RUN install_packages python3-pip
RUN pip3 install \
  beautifulsoup4==4.7.1 \
  lxml==4.3.1 \
  pycodestyle==2.5.0


FROM base AS ruby_deps
RUN install_packages \
  bundler \
    # Fetches ruby dependencies
  ruby-dev make cmake gcc libc-dev patch
    # Required to compile some of the native dependencies
RUN bundle config --global silence_root_warning 1
COPY Gemfile* /
# --frozen forces us to regenerate Gemfile.lock locally before using it in
# docker which lets us lock the versions in place.
RUN bundle install --binstubs --system --frozen
COPY .docker/asciidoctor_2_0_10.patch /
RUN cd /var/lib/gems/2.5.0/gems/asciidoctor-2.0.10 && patch -p1 < /asciidoctor_2_0_10.patch


FROM base AS node_deps
COPY .docker/apt/keys/yarn.gpg /
RUN apt-key add /yarn.gpg
COPY .docker/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/
RUN install_packages yarn
COPY package.json /
COPY yarn.lock /
ENV YARN_CACHE_FOLDER=/tmp/.yarn-cache
# --frozen-lockfile forces us to regenerate yarn.lock locally before using it
# in docker which lets us lock the versions in place.
RUN yarn install --frozen-lockfile


FROM base AS final
LABEL MAINTAINERS="Nik Everett <nik@elastic.co>"
RUN install_packages \
  git \
    # Clone source repositories and commit to destination repositories
  libnss-wrapper \
    # Used to clean up user id differences in the docker image.
  libxml2-utils \
    # Validates the docsbook xml
  make \
    # Used by the tests
  nginx \
    # Serves docs during tests and when the container is used for "preview" or
    # "air gapped" docs
  openssh-client \
    # Used by git
  openssh-server \
    # Used to forward git authentication to the image on OSX
  perl-base \
    # The "glue" of the docs build is written in perl
  xsltproc \
    # Converts the docbook xml into html
    # Perl libraries used by the docs build
  libcapture-tiny-perl \
  libfile-copy-recursive-perl \
  libparallel-forkmanager-perl \
  libpath-class-perl \
  libxml-libxml-perl \
  libyaml-perl

COPY --from=node_deps /node_modules /node_modules
COPY --from=py_deps /usr/local/lib/python3.7/dist-packages /usr/local/lib/python3.7/dist-packages
COPY --from=py_deps /usr/local/bin/pycodestyle /usr/local/bin/pycodestyle
COPY --from=ruby_deps /var/lib/gems /var/lib/gems
COPY --from=ruby_deps /usr/local/bin/asciidoctor /usr/local/bin/asciidoctor
COPY --from=ruby_deps /usr/local/bin/rspec /usr/local/bin/rspec
COPY --from=ruby_deps /usr/local/bin/rubocop /usr/local/bin/rubocop

# We mount these directories with tmpfs so we can write to them so they
# have to be empty. So we delete them.
RUN rm -rf /var/log/nginx && rm -rf /run/nginx
