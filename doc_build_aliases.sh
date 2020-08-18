# Aliases for building the docs.

# Edit your .bash_profile. Copy the following two lines into the file
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

# Logstash 6.2 and earlier

alias docbldlsold='$GIT_HOME/docs/build_docs --doc $GIT_HOME/logstash/docs/index.x.asciidoc --resource=$GIT_HOME/logstash-docs/docs/ --resource=$GIT_HOME/logstash-extra/x-pack-logstash/docs/ --chunk 1'

# Installation and Upgrade Guide 7.0 and later
alias docbldstk='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/install-upgrade/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/ --resource=$GIT_HOME/kibana/docs/ --resource=$GIT_HOME/beats/libbeat/docs/ --resource=$GIT_HOME/apm-server/docs/guide --resource=$GIT_HOME/logstash/docs/ --resource=$GIT_HOME/elasticsearch-hadoop/docs/src/reference/asciidoc/ --chunk 1'

# Installation and Upgrade Guide 6.7 and earlier
alias docbldstkold='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/install-upgrade/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/ --chunk 1'


# Glossary
alias docbldgls='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/glossary/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs --resource=$GIT_HOME/kibana/docs'

# Getting started
alias docbldgs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/getting-started/index.asciidoc --chunk 1'

# Stack Overview
alias docbldso='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/stack/index.asciidoc --resource $GIT_HOME/elasticsearch/docs --chunk 1'

# Stack Overview versions 6.3-7.2
alias docbldsoold=docbldso

# Deploying Azure
alias docbldaz='$GIT_HOME/docs/build_docs --doc $GIT_HOME/azure-marketplace/docs/index.asciidoc --chunk 1'

# Solutions
alias docbldob='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/observability/index.asciidoc --chunk 1 --resource $GIT_HOME/beats/libbeat/docs --resource $GIT_HOME/apm-server/docs/guide'

alias docbldmet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/metrics/index.asciidoc --chunk 1'

alias docbldlog='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/logs/index.asciidoc --chunk 1'

alias docbldup='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/uptime/index.asciidoc --chunk 1'

alias docbldsec='$GIT_HOME/docs/build_docs --doc $GIT_HOME/security-docs/docs/index.asciidoc --resource $GIT_HOME/stack-docs/docs --chunk 1'

alias docbldepd='$GIT_HOME/docs/build_docs --doc $GIT_HOME/stack-docs/docs/en/endpoint/index.asciidoc --chunk 1'

alias docbldees='$GIT_HOME/docs/build_docs --doc $GIT_HOME/enterprise-search-docs/index.asciidoc --chunk=1'

alias docbldews='$GIT_HOME/docs/build_docs --doc $GIT_HOME/workplace-search-docs/index.asciidoc --chunk=1'

alias docbldas='$GIT_HOME/docs/build_docs --doc $GIT_HOME/app-search-docs/index.asciidoc --chunk=1'

# Curator
alias docbldcr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/curator/docs/asciidoc/index.asciidoc'

# Cloud
alias docbldec='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud/docs/saas/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --chunk 1'

alias docbldess=docbldec

# Cloud - Elastic Cloud Enterprise
alias docbldece='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud/docs/cloud-enterprise/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --resource=$GIT_HOME/cloud-assets/docs --chunk 2'

alias docbldech='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud/docs/heroku/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --resource=$GIT_HOME/cloud/docs/saas --chunk 1'

# Cloud - Elastic Cloud Control
alias docbldecctl='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecctl/docs/index.asciidoc --chunk 1'

# Cloud - Elastic Cloud for K8s
alias docbldk8s='$GIT_HOME/docs/build_docs --doc $GIT_HOME/cloud-on-k8s/docs/index.asciidoc --chunk 1'

# Beats
alias docbldbpr='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/libbeat/docs/index.asciidoc --chunk 1'

alias docbldbdg='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/docs/devguide/index.asciidoc --chunk 1'

alias docbldpb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/packetbeat/docs/index.asciidoc --chunk 1'

alias docbldfb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/filebeat/docs/index.asciidoc --chunk 1'

alias docbldwb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/winlogbeat/docs/index.asciidoc --chunk 1'

alias docbldmb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/metricbeat/docs/index.asciidoc --chunk 1'

alias docbldhb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/heartbeat/docs/index.asciidoc --chunk 1'

alias docbldab='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/auditbeat/docs/index.asciidoc --chunk 1'
alias docbldabx='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/auditbeat/docs/index.asciidoc --resource=$GIT_HOME/beats/x-pack/auditbeat --chunk 1'

alias docbldfnb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/x-pack/functionbeat/docs/index.asciidoc --chunk 1'

alias docbldjb='$GIT_HOME/docs/build_docs --respect_edit_url_overrides --doc $GIT_HOME/beats/journalbeat/docs/index.asciidoc --chunk 1'

# Ingest management
alias docbldim='$GIT_HOME/docs/build_docs --doc $GIT_HOME/observability-docs/docs/en/ingest-management/index.asciidoc --resource=$GIT_HOME/beats/x-pack/elastic-agent/docs --chunk 1'

# APM
alias docbldamg='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-server/docs/guide/index.asciidoc --chunk 1'

alias docbldamr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-server/docs/index.asciidoc --chunk 1'

alias docbldamn='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-nodejs/docs/index.asciidoc --chunk 1'

alias docbldamp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-python/docs/index.asciidoc --chunk 1'

alias docbldamry='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-ruby/docs/index.asciidoc --chunk 1'

alias docbldamj='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-java/docs/index.asciidoc --chunk 1'

alias docbldamjs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-rum-js/docs/index.asciidoc --chunk 1'

alias docbldamgo='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-go/docs/index.asciidoc --chunk 1'

alias docbldamnet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/apm-agent-dotnet/docs/index.asciidoc --chunk 1'


# Definitive Guide
alias docblddg='$GIT_HOME/docs/build_docs --suppress_migration_warnings --doc $GIT_HOME/elasticsearch-definitive-guide/book.asciidoc --chunk 1'


# Elasticsearch Extras
alias docbldres='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/resiliency/index.asciidoc --single --toc'

alias docbldpls='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/painless/index.asciidoc --chunk 1'

alias docbldepi='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/plugins/index.asciidoc --chunk 2'

alias docbldjvr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/java-rest/index.asciidoc --chunk 1'

alias docbldejv='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/java-api/index.asciidoc --chunk 1'

alias docbldejs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-js/docs/index.asciidoc'

alias docblderb='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-ruby/docs/index.asciidoc --chunk 1'

alias docbldegr='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/groovy-api/index.asciidoc'

alias docbldego='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/go/index.asciidoc --single'

alias docbldnet='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-net/docs/index.asciidoc --chunk 1'

alias docbldphp='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-php/docs/index.asciidoc'

alias docbldepl='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/perl/index.asciidoc --single'

alias docbldepy='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/python/index.asciidoc --single'

alias docbldecc='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch/docs/community-clients/index.asciidoc --single'

alias docbldesh='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-hadoop/docs/src/reference/asciidoc/index.adoc'

alias docbldela='$GIT_HOME/docs/build_docs --doc $GIT_HOME/elasticsearch-eland-docs/docs/en/index.asciidoc --single'

# X-Pack Reference 5.4 to 6.2

alias docbldx='$GIT_HOME/docs/build_docs --doc $GIT_HOME/x-pack/docs/en/index.asciidoc --resource=$GIT_HOME/kibana-extra/x-pack-kibana/docs --resource=$GIT_HOME/elasticsearch-extra/x-pack-elasticsearch/docs --chunk 1'

# ECS
alias docbldecs='$GIT_HOME/docs/build_docs --doc $GIT_HOME/ecs/docs/index.asciidoc --chunk 1'

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
