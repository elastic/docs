# Aliases for building the docs.

# Edit your .bash_profile. Copy the following two lines into the file
# to set the $GIT_HOME variable to the directory that
# contains your local copies of the elastic repos and include this file.
#
#    export GIT_HOME="/<fullPathTYourRepos>"
#    source $GIT_HOME/docs/doc_build_aliases.sh
#
# These aliases assume that you have cloned the elastic repos according to
# the directory layout described in https://github.com/elastic/x-pack/blob/master/README.md


# Elasticsearch
alias docbldesx='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch/docs/reference/index.asciidoc --resource=$GIT_HOME/elasticsearch/x-pack/docs/ --chunk 1'

alias docbldes=docbldesx

# Elasticsearch 6.2 and earlier

alias docbldesold='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch/docs/reference/index.x.asciidoc --resource=$GIT_HOME/elasticsearch-extra/x-pack-elasticsearch/docs/ --chunk 1'

# Kibana
alias docbldkbx='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/kibana/docs/index.asciidoc --chunk 1'

alias docbldkb=docbldkbx

# Kibana 6.2 and earlier

alias docbldkbold='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/kibana/docs/index.x.asciidoc --resource=$GIT_HOME/kibana-extra/x-pack-kibana/docs/ --chunk 1'

# Logstash
alias docbldlsx='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/logstash/docs/index.asciidoc --resource=$GIT_HOME/logstash-docs/docs/ --chunk 1'

alias docbldls=docbldlsx

# Logstash 6.2 and earlier

alias docbldlsold='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/logstash/docs/index.x.asciidoc --resource=$GIT_HOME/logstash-docs/docs/ --resource=$GIT_HOME/logstash-extra/x-pack-logstash/docs/ --chunk 1'

# Stack
alias docbldstk='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/stack-docs/docs/en/install-upgrade/index.asciidoc --resource=$GIT_HOME/elasticsearch/docs/ --resource=$GIT_HOME/kibana/docs/'

alias docbldgls='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/stack-docs/docs/en/glossary/index.asciidoc'

alias docbldgs='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/stack-docs/docs/en/getting-started/index.asciidoc --chunk 1'

alias docbldso='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/stack-docs/docs/en/stack/index.asciidoc --resource=$GIT_HOME/kibana/docs --resource=$GIT_HOME/elasticsearch/x-pack/docs --resource=$GIT_HOME/elasticsearch/docs --chunk 1'

alias docbldaz='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/azure-marketplace/docs/index.asciidoc --chunk 1'

alias docbldinf='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/stack-docs/docs/en/infraops/index.asciidoc --chunk 1'

# Curator
alias docbldcr='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/curator/docs/asciidoc/index.asciidoc'

# Cloud
alias docbldec='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/cloud/docs/saas/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --chunk 1'

alias docbldece='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/cloud/docs/cloud-enterprise/index.asciidoc --resource=$GIT_HOME/cloud/docs/shared --chunk 1'

# Beats
alias docbldbpr='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/libbeat/docs/index.asciidoc --chunk 1'

alias docbldbdg='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/docs/devguide/index.asciidoc --chunk 1'

alias docbldpb='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/packetbeat/docs/index.asciidoc --chunk 1'

alias docbldfb='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/filebeat/docs/index.asciidoc --chunk 1'

alias docbldwb='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/winlogbeat/docs/index.asciidoc --chunk 1'

alias docbldmb='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/metricbeat/docs/index.asciidoc --chunk 1'

alias docbldhb='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/heartbeat/docs/index.asciidoc --chunk 1'

alias docbldab='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/auditbeat/docs/index.asciidoc --chunk 1'
alias docbldabx='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/beats/auditbeat/docs/index.asciidoc --resource=$GIT_HOME/beats/x-pack/auditbeat --chunk 1'

# APM
alias docbldamg='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/apm-server/docs/guide/index.asciidoc --chunk 1'

alias docbldamr='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/apm-server/docs/index.asciidoc --chunk 1'

alias docbldamn='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-nodejs/docs/index.asciidoc --chunk 1'

alias docbldamp='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-python/docs/index.asciidoc --chunk 1'

alias docbldamry='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-ruby/docs/index.asciidoc --chunk 1'

alias docbldamj='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-java/docs/index.asciidoc --chunk 1'

alias docbldamjs='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-rum-js/docs/index.asciidoc --chunk 1'

alias docbldamgo='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-go/docs/index.asciidoc --chunk 1'

alias docbldamnet='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/apm-agent-dotnet/docs/index.asciidoc --chunk 1'


# Definitive Guide
alias docblddg='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch-definitive-guide/book.asciidoc --chunk 1'


# Elasticsearch Extras
alias docbldres='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/resiliency/index.asciidoc --single'

alias docbldpls='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch/docs/painless/index.asciidoc --chunk 1'

alias docbldepi='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch/docs/plugins/index.asciidoc --chunk 2'

alias docbldjvr='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch/docs/java-rest/index.asciidoc --chunk 1'

alias docbldejv='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch/docs/java-api/index.asciidoc --chunk 1'

alias docbldejs='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch-js/docs/index.asciidoc'

alias docbldegr='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/groovy-api/index.asciidoc'

alias docbldego='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/go/index.asciidoc'

alias docbldnet='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch-net/docs/index.asciidoc --chunk 1'

alias docbldphp='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch-php/docs/index.asciidoc'

alias docbldepl='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/perl/index.asciidoc --single'

alias docbldepy='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/python/index.asciidoc --single'

alias docblderb='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/ruby/index.asciidoc'

alias docbldecc='$GIT_HOME/docs/build_docs --asciidoctor --doc $GIT_HOME/elasticsearch/docs/community-clients/index.asciidoc --single'

alias docbldesh='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/elasticsearch-hadoop/docs/src/reference/asciidoc/index.adoc'

# X-Pack Reference 5.4 to 6.2

alias docbldx='$GIT_HOME/docs/build_docs.pl --doc $GIT_HOME/x-pack/docs/en/index.asciidoc --resource=$GIT_HOME/kibana-extra/x-pack-kibana/docs --resource=$GIT_HOME/elasticsearch-extra/x-pack-elasticsearch/docs --chunk 1'
