#!/bin/bash
# Aliases for building the docs.

# Edit your .bash_profile or .zshrc. Copy the following two lines into the file
# to set the $GIT_HOME variable to the directory that
# contains your local copies of the elastic repos and include this file.
#
#    export GIT_HOME="/<fullPathTYourRepos>"
#    source $GIT_HOME/docs/doc_build_aliases.sh
#

# Elasticsearch
alias docbldesx='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/reference/index.asciidoc --resource=$GIT_HOME/elasticsearch/x-pack/docs/ --chunk 1'

alias docbldes=docbldesx

# Elasticsearch 6.2 and earlier

alias docbldesold='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/reference/index.x.asciidoc --resource=$GIT_HOME/elasticsearch-extra/x-pack-elasticsearch/docs/ --chunk 1'

# Kibana
alias docbldkbx='$GIT_HOME/docs/build_docs --doc $GIT_HOME/kibana/docs/index.asciidoc --chunk 1'

alias docbldkb=docbldkbx

# Kibana 6.2 to 5.3

alias docbldkbold='$GIT_HOME/docs/build_docs --doc $GIT_HOME/kibana/docs/index.x.asciidoc --resource=$GIT_HOME/kibana-extra/x-pack-kibana/docs/ --chunk 1'

# Logstash
alias docbldlsx='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/logstash/docs/index.asciidoc --resource=$GIT_HOME/logstash-docs/docs/ --chunk 1'

alias docbldls=docbldlsx

alias docbldlsk8s='$GIT_HOME/docs/build_docs --doc $GIT_HOME/logstash/docs/k8sdocs/index.asciidoc --chunk 1'

# Logstash 6.2 and earlier

alias docbldlsold='$GIT_HOME/docs/build_docs --doc $GIT_HOME/logstash/docs/index.x.asciidoc --resource=$GIT_HOME/logstash-docs/docs/ --resource=$GIT_HOME/logstash-extra/x-pack-logstash/docs/ --chunk 1'

# Logstash Versioned Plugin Reference
docbldlsvpr() {
    pushd "$GIT_HOME/logstash-docs" || return
    # Make sure the right branch is checked out
    git checkout versioned_plugin_docs
    git pull
    popd || return
    "$GIT_HOME/docs/build_docs" --doc "$GIT_HOME/logstash-docs/docs/versioned-plugins/index.asciidoc" --chunk 1 "$@"
}

# Installation and Upgrade Guide 7.10 and later
alias docbldstk='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/install-upgrade/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/ --resource=$GIT_HOME/kibana/docs/ --resource=$GIT_HOME/beats/libbeat/docs/ --resource=$GIT_HOME/apm-server/docs/guide --resource=$GIT_HOME/observability-docs/docs/en/observability --resource=$GIT_HOME/logstash/docs/ --resource=$GIT_HOME/elasticsearch-hadoop/docs/src/reference/asciidoc/ --resource=$GIT_HOME/security-docs/docs/ --chunk 1'

# Installation and Upgrade Guide 7.0 to 7.9
alias docbldstkold2='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/install-upgrade/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/ --resource=$GIT_HOME/kibana/docs/ --resource=$GIT_HOME/beats/libbeat/docs/ --resource=$GIT_HOME/apm-server/docs/guide --resource=$GIT_HOME/logstash/docs/ --resource=$GIT_HOME/elasticsearch-hadoop/docs/src/reference/asciidoc/ --chunk 1'

# Installation and Upgrade Guide 6.7 and earlier
alias docbldstkold='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/install-upgrade/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/ --chunk 1'

# Elastic general
alias docbldestc='$GIT_HOME/docs/build_docs --doc $GIT_HOME/tech-content/welcome-to-elastic/index.asciidoc --chunk 1'

# Glossary
alias docbldgls='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/glossary/index.asciidoc'

# Getting started
alias docbldgs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/getting-started/index.asciidoc --resource $GIT_HOME/elasticsearch/docs --chunk 1'

# Stack Overview
alias docbldso='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/stack/index.asciidoc --resource $GIT_HOME/elasticsearch/docs --chunk 1'

# Stack Overview versions 6.3-7.2
alias docbldsoold=docbldso

# Deploying Azure
alias docbldaz='$GIT_HOME/docs/build_docs --doc $GIT_HOME/azure-marketplace/docs/index.asciidoc --chunk 1'

# Solutions
alias docbldsec='$GIT_HOME/docs/build_docs --doc $GIT_HOME/security-docs/docs/index.asciidoc --resource $GIT_HOME/stack-docs/docs --chunk 1'

alias docbldepd='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/endpoint/index.asciidoc --chunk 1'

alias docbldees='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-pubs/enterprise-search-docs/index.asciidoc --chunk=1'

alias docbldeas='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-pubs/app-search-docs/index.asciidoc --chunk=1'

alias docbldews='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-pubs/workplace-search-docs/index.asciidoc --chunk=1'

alias docbldeasj='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-pubs/client-docs/app-search-javascript/index.asciidoc --single'

alias docbldeasn='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-pubs/client-docs/app-search-node/index.asciidoc --single'

alias docbldeesphp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-php/docs/guide/index.asciidoc'

alias docbldeesp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-python/docs/guide/index.asciidoc'

alias docbldeesr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-ruby/docs/guide/index.asciidoc'

alias docbldewsn='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-pubs/client-docs/workplace-search-node/index.asciidoc --single'

# Observability Guide
alias docbldob='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/observability/index.asciidoc --chunk 2 --resource $GIT_HOME/beats/libbeat/docs --resource $GIT_HOME/apm-server/docs/guide'

# Observability Legacy
alias docbldmet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/metrics/index.asciidoc --chunk 1'

alias docbldlog='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/logs/index.asciidoc --chunk 1'

alias docbldup='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/uptime/index.asciidoc --chunk 1'

# Curator
alias docbldcr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/curator/docs/asciidoc/index.asciidoc'

# Cloud
alias docbldec='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud/docs/saas/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --chunk 1'

alias docbldess=docbldec

# Cloud - Elastic Cloud Enterprise
alias docbldece='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud/docs/cloud-enterprise/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --resource=$GIT_HOME/cloud-assets/docs --chunk 2'

alias docbldech='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud/docs/heroku/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --resource=$GIT_HOME/cloud/docs/saas --chunk 1'

# Cloud - Elastic Cloud on Kubernetes
alias docbldeck='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud-on-k8s/docs/index.asciidoc --chunk 1'

# Cloud - Elastic Cloud Control
alias docbldecctl='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecctl/docs/index.asciidoc --chunk 1'

# Cloud - Elastic Cloud for K8s
alias docbldk8s='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud-on-k8s/docs/index.asciidoc --chunk 1'

# Cloud - Terraform provider
alias docbldtpec='$GIT_HOME/docs/build_docs --doc $GIT_HOME/terraform-provider-ec/docs-elastic/index.asciidoc --chunk 1 --single'

# Beats
alias docbldbpr='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/libbeat/docs/index.asciidoc --chunk 1'

alias docbldbdg='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/docs/devguide/index.asciidoc --chunk 1'

alias docbldpb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/packetbeat/docs/index.asciidoc --chunk 1'

alias docbldfb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/filebeat/docs/index.asciidoc --resource=$GIT_HOME/beats/x-pack/filebeat/docs --chunk 1'

alias docbldwb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/winlogbeat/docs/index.asciidoc --chunk 1'

alias docbldmb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/metricbeat/docs/index.asciidoc --chunk 1'

alias docbldhb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/heartbeat/docs/index.asciidoc --chunk 1'

alias docbldab='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/auditbeat/docs/index.asciidoc --chunk 1'
alias docbldabx='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/auditbeat/docs/index.asciidoc --resource=$GIT_HOME/beats/x-pack/auditbeat --chunk 1'

alias docbldfnb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/x-pack/functionbeat/docs/index.asciidoc --chunk 1'

alias docbldjb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/journalbeat/docs/index.asciidoc --chunk 1'

# Fleet and Elastic Agent guide
alias docbldim='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/ingest-management/index.asciidoc --resource=$GIT_HOME/apm-server/docs --chunk 2'

# Integrations developer guide
alias docbldidg='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/integrations/index.asciidoc --resource=$GIT_HOME/package-spec/versions --chunk 2'

# APM Guide
alias docbldapm=' $GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-server/docs/integrations-index.asciidoc --resource=$GIT_HOME/observability-docs/ --resource=$GIT_HOME/apm-aws-lambda/ --resource=$GIT_HOME/apm-mutating-webhook/ --chunk 2 --open'

# APM Agents
alias docbldamn='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-nodejs/docs/index.asciidoc --chunk 1 --resource $GIT_HOME/apm-aws-lambda/docs'

alias docbldamp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-python/docs/index.asciidoc --chunk 1 --resource $GIT_HOME/apm-aws-lambda/docs'

alias docbldamry='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-ruby/docs/index.asciidoc --chunk 1'

alias docbldamj='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-java/docs/index.asciidoc --chunk 1 --resource $GIT_HOME/apm-aws-lambda/docs'

alias docbldamjs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-rum-js/docs/index.asciidoc --chunk 1'

alias docbldamgo='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-go/docs/index.asciidoc --chunk 1'

alias docbldamnet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-dotnet/docs/index.asciidoc --chunk 1'

alias docbldamphp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-php/docs/index.asciidoc --chunk 1'

alias docbldamios='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-ios/docs/index.asciidoc --chunk 1'

# APM Legacy
alias docbldamg='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-server/docs/guide/index.asciidoc --chunk 1'

alias docbldamr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-server/docs/index.asciidoc --chunk 1'

# Definitive Guide
alias docblddg='$GIT_HOME/docs/build_docs --suppress_migration_warnings --doc $GIT_HOME/elasticsearch-definitive-guide/book.asciidoc --chunk 1'

# Elasticsearch Extras
alias docbldres='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/resiliency/index.asciidoc --single --toc'

alias docbldpls='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/painless/index.asciidoc --chunk 1'

alias docbldepi='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/plugins/index.asciidoc --chunk 2'

alias docbldjva='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-java/docs/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/java-rest --resource=$GIT_HOME/elasticsearch/client --chunk 1'

alias docbldjvr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/java-rest/index.asciidoc --chunk 1'

alias docbldejv='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/java-api/index.asciidoc --chunk 1'

alias docbldejs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-js/docs/index.asciidoc --chunk 1'

alias docblderb='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-ruby/docs/index.asciidoc --chunk 1'

alias docbldegr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/groovy-api/index.asciidoc'

alias docbldego='$GIT_HOME/docs/build_docs --doc $GIT_HOME/go-elasticsearch/.doc/index.asciidoc --chunk 1'

alias docbldnet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-net/docs/index.asciidoc --chunk 1'

alias docbldphp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-php/docs/index.asciidoc --chunk 1'

alias docbldepl='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/perl/index.asciidoc --chunk 1'

alias docbldepy='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-py/docs/guide/index.asciidoc --chunk 1'

alias docblders='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-rs/docs/index.asciidoc --chunk 1'

alias docbldecc='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/community-clients/index.asciidoc --single'

alias docbldesh='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-hadoop/docs/src/reference/asciidoc/index.adoc'

alias docbldela='$GIT_HOME/docs/build_docs --doc $GIT_HOME/eland/docs/guide/index.asciidoc --chunk 1'

alias docbldejsl='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-js-legacy/docs/index.asciidoc --chunk 1'

# X-Pack Reference 5.4 to 6.2

alias docbldx='$GIT_HOME/docs/build_docs --doc $GIT_HOME/x-pack/docs/en/index.asciidoc --resource=$GIT_HOME/kibana-extra/x-pack-kibana/docs --resource=$GIT_HOME/elasticsearch-extra/x-pack-elasticsearch/docs --chunk 1'

# ECS
alias docbldecs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs/docs/index.asciidoc --chunk 2'

# ECS logging
alias docbldecslg='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging/docs/index.asciidoc --chunk 1'

alias docbldecslrs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-go-logrus/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecszap='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-go-zap/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecsjv='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-java/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecsnet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-dotnet/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecsnodejs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-nodejs/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecsphp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-php/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecspy='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-python/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

alias docbldecsrb='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs-logging-ruby/docs/index.asciidoc --resource=$GIT_HOME/ecs-logging/docs/ --chunk 1'

# GKE
alias docbldgke='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/gke-on-prem/index.asciidoc --chunk 1'

# Build all
alias docbldall='$GIT_HOME/docs/build_docs --all --target_repo git@github.com:elastic/built-docs.git'
# NOTE: To build all books and pick up un-merged changes from your local repos,
# use one or more --sub_dir options. Specify the repo and branch you want to
# override and the directory that contains your changes.
# Do not include the docs repo in this list. The build always uses your local files.
# For example:
# --sub_dir elasticsearch:master:./elasticsearch

# Machine learning
alias docbldml='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/stack/ml/index.asciidoc --resource $GIT_HOME/elasticsearch/docs --chunk 1'
