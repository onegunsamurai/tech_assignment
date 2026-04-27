{{/*
Resource name helper. Truncated to 63 chars to satisfy DNS-1123.
*/}}
{{- define "pet-operator.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "pet-operator.labels" -}}
app.kubernetes.io/name: pet-operator
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: pet-system
{{- end -}}

{{- define "pet-operator.selectorLabels" -}}
app.kubernetes.io/name: pet-operator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
