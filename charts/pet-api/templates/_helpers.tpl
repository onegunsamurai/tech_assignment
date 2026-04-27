{{- define "pet-api.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "pet-api.labels" -}}
app.kubernetes.io/name: pet-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: pet-system
{{- end -}}

{{- define "pet-api.selectorLabels" -}}
app.kubernetes.io/name: pet-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
