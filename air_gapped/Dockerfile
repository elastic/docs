FROM docker.elastic.co/docs/preview:latest AS build

COPY air_gapped/work/target_repo.git /docs_build/.repos/target_repo.git

FROM debian:trixie-slim
#FROM perl:5.42-bookworm

RUN apt update -y
RUN apt-get install -y perl
RUN apt-get install -y nginx
RUN apt-get install -y nodejs
RUN apt-get install -y git

RUN apt-get install -y libxml-simple-perl
RUN apt-get install -y libfile-copy-recursive-perl
RUN apt-get install -y libpath-class-perl
RUN apt-get install -y libcapture-tiny-perl
RUN apt-get install -y libparallel-forkmanager-perl
RUN apt-get install -y libyaml-perl

COPY --from=build /docs_build /docs_build
COPY --from=build /node_modules /node_modules

CMD ["/docs_build/build_docs.pl", "--in_standard_docker", "--gapped", "--preview"]

