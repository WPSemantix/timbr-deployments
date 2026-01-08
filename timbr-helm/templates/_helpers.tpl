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
*/}}
{{- define "timbr.storageClass" -}}
{{- $storageClass := . -}}
{{- if $storageClass -}}
{{ $storageClass }}
{{- else -}}
{{- if eq $.Values.cloudProvider.type "aws" -}}
gp3
{{- else if eq $.Values.cloudProvider.type "azure" -}}
managed-csi
{{- else if eq $.Values.cloudProvider.type "gcp" -}}
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
nginx.ingress.kubernetes.io/rewrite-target: /
{{- end }}
{{- /* Merge user-provided annotations */ -}}
{{- with .Values.ingress.annotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}
