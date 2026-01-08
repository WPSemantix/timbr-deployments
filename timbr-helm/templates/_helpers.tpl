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
