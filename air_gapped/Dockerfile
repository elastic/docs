FROM docker.elastic.co/docs/preview:latest

COPY air_gapped/work/target_repo.git /docs_build/.repos/target_repo.git

CMD ["/docs_build/build_docs.pl", "--in_standard_docker", "--gapped", "--preview"]
