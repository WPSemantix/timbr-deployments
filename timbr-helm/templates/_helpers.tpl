{{- define "timbr.labels" -}}
app.kubernetes.io/name: timbr
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "timbr.secretName" -}}
{{- if .Values.secrets.existingSecretName -}}
{{ .Values.secrets.existingSecretName }}
{{- else -}}
timbr-secrets
{{- end -}}
{{- end }}

{{- define "timbr.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
=============================================================================
Database backend helpers.

`db.type` (mysql | postgres) selects the metadata database, exactly the way
`cloudProvider.type` selects the cloud. Component templates must never branch
on the backend themselves - extend these helpers instead.

An explicit `.Values.db.*` setting always wins over the type-based default.
=============================================================================
*/}}

{{/*
Truthy (non-empty) only when the PostgreSQL backend is selected.
Usage: {{- if include "timbr.db.isPostgres" . }}
*/}}
{{- define "timbr.db.isPostgres" -}}
{{- if eq .Values.db.type "postgres" -}}
true
{{- end -}}
{{- end -}}

{{- define "timbr.db.host" -}}
{{- if .Values.db.host -}}
{{ .Values.db.host }}
{{- else if eq .Values.db.type "postgres" -}}
{{ .Values.postgres.name }}
{{- else -}}
{{ .Values.mysql.name }}
{{- end -}}
{{- end -}}

{{- define "timbr.db.port" -}}
{{- if .Values.db.port -}}
{{ .Values.db.port }}
{{- else if eq .Values.db.type "postgres" -}}
5432
{{- else -}}
3306
{{- end -}}
{{- end -}}

{{- define "timbr.db.user" -}}
{{- if .Values.db.user -}}
{{ .Values.db.user }}
{{- else if eq .Values.db.type "postgres" -}}
postgres
{{- else -}}
root
{{- end -}}
{{- end -}}

{{/*
Key inside the shared secret that holds the database password.
*/}}
{{- define "timbr.db.passwordSecretKey" -}}
{{- if .Values.db.passwordSecretKey -}}
{{ .Values.db.passwordSecretKey }}
{{- else if eq .Values.db.type "postgres" -}}
postgresPassword
{{- else -}}
{{ .Values.db.rootPasswordSecretKey }}
{{- end -}}
{{- end -}}

{{/*
SQLAlchemy dialect used by timbr-platform / timbr-api (DB_CONNECTION).
*/}}
{{- define "timbr.db.connection" -}}
{{- if eq .Values.db.type "postgres" -}}
postgresql+psycopg2
{{- else -}}
mysql
{{- end -}}
{{- end -}}

{{- define "timbr.db.jdbcDriver" -}}
{{- if eq .Values.db.type "postgres" -}}
org.postgresql.Driver
{{- else -}}
com.mysql.jdbc.Driver
{{- end -}}
{{- end -}}

{{/*
TIMBR_DB_JDBC_PARAMS. Empty for PostgreSQL - the MySQL params are not valid
there and an empty value must not render an env var.
*/}}
{{- define "timbr.db.jdbcParams" -}}
{{- if .Values.db.jdbcParams -}}
{{ .Values.db.jdbcParams }}
{{- else if eq .Values.db.type "postgres" -}}
{{- else -}}
useSSL=false&allowPublicKeyRetrieval=true
{{- end -}}
{{- end -}}

{{/*
Database that timbr-platform connects to (DB_DATABASE). Under PostgreSQL every
component shares one database and is separated by schema instead.
*/}}
{{- define "timbr.db.platformDbName" -}}
{{- if eq .Values.db.type "postgres" -}}
{{ .Values.db.database }}
{{- else -}}
{{ .Values.db.platformDb }}
{{- end -}}
{{- end -}}

{{/*
Timbr server metadata location (TIMBR_DB_NAME / TIMBR_SERVER_SCHEMA):
a database under MySQL, a schema under PostgreSQL.
*/}}
{{- define "timbr.db.serverDbName" -}}
{{- if eq .Values.db.type "postgres" -}}
{{ .Values.db.serverSchema }}
{{- else -}}
{{ .Values.db.serverDb }}
{{- end -}}
{{- end -}}

{{/*
JDBC URL used by timbr-server. PostgreSQL requires the database in the path.
*/}}
{{- define "timbr.db.jdbcUrl" -}}
{{- $host := include "timbr.db.host" . -}}
{{- $port := include "timbr.db.port" . -}}
{{- if eq .Values.db.type "postgres" -}}
{{ printf "jdbc:postgresql://%s:%s/%s" $host $port .Values.db.database }}
{{- else -}}
{{ printf "jdbc:mysql://%s:%s" $host $port }}
{{- end -}}
{{- end -}}

{{/*
JDBC URL used by timbr-mdx and timbr-ga (trailing-slash form under MySQL).
*/}}
{{- define "timbr.db.jdbcUrlSlash" -}}
{{- $host := include "timbr.db.host" . -}}
{{- $port := include "timbr.db.port" . -}}
{{- if eq .Values.db.type "postgres" -}}
{{ printf "jdbc:postgresql://%s:%s/%s" $host $port .Values.db.database }}
{{- else -}}
{{ printf "jdbc:mysql://%s:%s/" $host $port }}
{{- end -}}
{{- end -}}

{{/*
JDBC URL for the timbr-virtualization Hive metastore. A separate database under
MySQL; a schema inside the shared database under PostgreSQL.
*/}}
{{- define "timbr.db.metastoreJdbcUrl" -}}
{{- $host := include "timbr.db.host" . -}}
{{- $port := include "timbr.db.port" . -}}
{{- $params := include "timbr.db.jdbcParams" . -}}
{{- if eq .Values.db.type "postgres" -}}
{{ printf "jdbc:postgresql://%s:%s/%s?currentSchema=%s" $host $port .Values.db.database .Values.db.metastoreSchema }}
{{- else if $params -}}
{{ printf "jdbc:mysql://%s:%s/timbr_metastore?%s" $host $port $params }}
{{- else -}}
{{ printf "jdbc:mysql://%s:%s/timbr_metastore" $host $port }}
{{- end -}}
{{- end -}}

{{/*
Get the ingress class name based on cloud provider
*/}}
{{- define "timbr.ingressClass" -}}
{{- if .Values.ingress.className -}}
{{ .Values.ingress.className }}
{{- else -}}
{{- if eq .Values.cloudProvider.type "aws" -}}
alb
{{- else if eq .Values.cloudProvider.type "azure" -}}
azure-application-gateway
{{- else if eq .Values.cloudProvider.type "gcp" -}}
gce
{{- else -}}
nginx
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get the storage class name based on cloud provider
Usage: include "timbr.storageClass" (dict "root" . "storageClassName" .Values.mysql.persistence.storageClassName)
*/}}
{{- define "timbr.storageClass" -}}
{{- $storageClass := .storageClassName -}}
{{- if $storageClass -}}
{{ $storageClass }}
{{- else -}}
{{- if eq .root.Values.cloudProvider.type "aws" -}}
gp3
{{- else if eq .root.Values.cloudProvider.type "azure" -}}
managed-csi
{{- else if eq .root.Values.cloudProvider.type "gcp" -}}
standard-rwo
{{- else -}}
{{- /* Use cluster default if generic or not specified */ -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generate cloud-specific ingress annotations
*/}}
{{- define "timbr.ingressAnnotations" -}}
{{- if eq .Values.cloudProvider.type "aws" -}}
alb.ingress.kubernetes.io/scheme: {{ .Values.ingress.aws.scheme | quote }}
alb.ingress.kubernetes.io/target-type: {{ .Values.ingress.aws.targetType | quote }}
{{- if .Values.ingress.tls.enabled }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
alb.ingress.kubernetes.io/ssl-redirect: "443"
{{- if and (eq .Values.ingress.tls.source "acm") .Values.ingress.tls.certificateArn }}
alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.tls.certificateArn | quote }}
{{- end }}
{{- else }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
{{- end }}
{{- else if eq .Values.cloudProvider.type "azure" -}}
appgw.ingress.kubernetes.io/backend-protocol: {{ .Values.ingress.azure.backendProtocol | quote }}
{{- if .Values.ingress.azure.usePrivateIp }}
appgw.ingress.kubernetes.io/use-private-ip: "true"
{{- end }}
{{- if and .Values.ingress.tls.enabled .Values.ingress.azure.sslRedirect }}
appgw.ingress.kubernetes.io/ssl-redirect: "true"
{{- end }}
{{- if and .Values.ingress.tls.enabled (eq .Values.ingress.tls.source "keyvault") .Values.ingress.tls.azureKeyVault.secretId }}
appgw.ingress.kubernetes.io/appgw-ssl-certificate: {{ .Values.ingress.tls.azureKeyVault.secretId | quote }}
{{- end }}
{{- else if eq .Values.cloudProvider.type "gcp" -}}
{{- if .Values.ingress.gcp.staticIpName }}
kubernetes.io/ingress.global-static-ip-name: {{ .Values.ingress.gcp.staticIpName | quote }}
{{- end }}
{{- if .Values.ingress.gcp.globalStaticIp }}
kubernetes.io/ingress.class: "gce"
{{- else }}
kubernetes.io/ingress.class: "gce-internal"
{{- end }}
{{- if .Values.ingress.tls.enabled }}
networking.gke.io/managed-certificates: "timbr-managed-cert"
{{- end }}
{{- else -}}
{{- /* Generic/NGINX annotations */ -}}
{{- if .Values.ingress.tls.enabled }}
nginx.ingress.kubernetes.io/ssl-redirect: "true"
{{- end }}
{{- end }}
{{- /* Merge user-provided annotations */ -}}
{{- with .Values.ingress.annotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}
