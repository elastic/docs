FROM docker.elastic.co/docs/preview:latest AS build

COPY air_gapped/work/target_repo.git /docs_build/.repos/target_repo.git

FROM perl:5.42-bookworm

#RUN apt-get install libxml2 libxml2-dev
RUN cpan install -T XML::LibXML
RUN cpan install -T File::Copy::Recursive
RUN cpan install -T Path::Class
RUN cpan install -T Parallel::ForkManager
RUN cpan install -T YAML
RUN apt update -y
RUN apt-get install -y nginx
RUN apt-get install -y nodejs
COPY --from=build /docs_build /docs_build
COPY --from=build /node_modules /node_modules

CMD ["/docs_build/build_docs.pl", "--in_standard_docker", "--gapped", "--preview"]

