FROM cgr.dev/chainguard/wolfi-base

RUN apk update && apk add nodejs git npm

WORKDIR /app
COPY air_gapped/work/target_repo.git /docs_build/.repos/target_repo.git
COPY --chown=node:node preview /app/preview/
COPY --chown=node:node template /app/template/
COPY --chown=node:node preview/package.json /app/package.json
WORKDIR /app
RUN npm install

ENTRYPOINT ["node", "preview/cli.js", "git", "/docs_build/.repos/target_repo.git"]

