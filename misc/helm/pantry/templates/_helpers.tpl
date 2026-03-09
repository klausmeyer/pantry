{{- define "pantry.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "pantry.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "pantry.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "pantry.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "pantry.labels" -}}
helm.sh/chart: {{ include "pantry.chart" . }}
app.kubernetes.io/name: {{ include "pantry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "pantry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pantry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "pantry.backendName" -}}
{{- printf "%s-backend" (include "pantry.fullname" .) -}}
{{- end -}}

{{- define "pantry.frontendName" -}}
{{- printf "%s-frontend" (include "pantry.fullname" .) -}}
{{- end -}}

{{- define "pantry.backendCredentialsSecretName" -}}
{{- if .Values.backend.credentials.existingSecretName -}}
{{- .Values.backend.credentials.existingSecretName -}}
{{- else -}}
{{- printf "%s-backend-credentials" (include "pantry.fullname" .) -}}
{{- end -}}
{{- end -}}
