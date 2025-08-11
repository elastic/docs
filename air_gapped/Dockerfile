FROM docker.elastic.co/docs/preview:latest AS build

COPY air_gapped/work/target_repo.git /docs_build/.repos/target_repo.git

FROM chainguard/wolfi-base:latest
#FROM perl:5.42-bookworm
RUN apk update
RUN apk add perl
RUN apk add curl
RUN apk add perl-app-cpanminus

RUN apk add gcc make git patch perl-dev wget
RUN apk add openssl-dev
RUN apk add zlib-dev
RUN apk add perl-net-ssleay

ENV PERL5LIB=/usr/local/lib/perl5
ENV PATH=/usr/local/bin:$PATH

WORKDIR /
RUN cpanm -n XML::LibXML
RUN cpanm -n File::Copy::Recursive
RUN cpanm -n Path::Class
RUN cpanm -n Parallel::ForkManager
RUN cpanm -n YAML
#RUN apt update -y
#RUN apt-get install -y perl
#RUN apt-get install -y nginx
#RUN apt-get install -y nodejs
#RUN apt-get install -y git

#RUN apt-get install -y libxml-simple-perl
#RUN apt-get install -y libfile-copy-recursive-perl
#RUN apt-get install -y libpath-class-perl
#RUN apt-get install -y libcapture-tiny-perl
#RUN apt-get install -y libparallel-forkmanager-perl
#RUN apt-get install -y libyaml-perl

RUN apk add nginx
RUN apk add nodejs

COPY --from=build /docs_build /docs_build
COPY --from=build /node_modules /node_modules

RUN adduser -D nginx
RUN mkdir -p /var/lib/nginx/tmp/

CMD ["/docs_build/build_docs.pl", "--in_standard_docker", "--gapped", "--preview"]

