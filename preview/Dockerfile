FROM docker.elastic.co/docs/build:1

RUN mkdir /var/log/nginx
RUN mkdir -p /run/nginx

# Limit the memory used by git gc so we can be good k8s citizens.
RUN git config --global pack.windowMemory 500m
RUN git config --global pack.deltaCacheSize 10m
RUN git config --global pack.threads 1

COPY build_docs.pl /docs_build/
COPY conf.yaml /docs_build/
COPY lib /docs_build/lib
COPY preview /docs_build/preview
COPY template /docs_build/template
COPY resources /docs_build/resources

CMD ["/docs_build/build_docs.pl", "--in_standard_docker", \
     "--preview", "--target_repo", "https://github.com/elastic/built-docs.git"]
