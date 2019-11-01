FROM docker.elastic.co/docs/build:latest

RUN mkdir /var/log/nginx
RUN mkdir -p /run/nginx

# Limit the memory used by git gc so we can be good k8s citizens.
RUN git config --global pack.windowMemory 500m
RUN git config --global pack.deltaCacheSize 10m
RUN git config --global pack.threads 1
# Prevent git auto-gc from warning about too many references by increasing the
# threshold of unreachable objects that triggers a prune and more aggressively
# pruning those unreachable objects. While we're at it we more aggressively
# prune the reflog as well. It is important to prevent corruption that we do
# leave *some* grace period in all of these (see the note in docs for git gc
# for more about this).
RUN git config --global gc.auto 20000
RUN git config --global gc.pruneExpire 1.hour.ago
RUN git config --global gc.reflogExpire 1.hour.ago
RUN git config --global gc.reflogExpireUnreachable 1.hour.ago

COPY build_docs.pl /docs_build/
COPY conf.yaml /docs_build/
COPY lib /docs_build/lib
COPY preview /docs_build/preview
COPY template /docs_build/template
COPY resources /docs_build/resources

CMD ["/docs_build/build_docs.pl", "--in_standard_docker", \
     "--preview", "--target_repo", "git@github.com:elastic/built-docs.git"]
