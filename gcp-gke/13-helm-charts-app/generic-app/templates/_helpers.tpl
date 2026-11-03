{{- define "generic-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "generic-app.fullname" -}}
{{- if .Values.releaseName -}}
{{- .Values.releaseName | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "generic-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "generic-app.labels" -}}
helm.sh/chart: {{ include "generic-app.chart" . }}
app.kubernetes.io/name: {{ include "generic-app.name" . }}
app.kubernetes.io/instance: {{ .Values.releaseName | default .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "generic-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic-app.name" . }}
app.kubernetes.io/instance: {{ .Values.releaseName | default .Release.Name }}
{{- end -}}

{{- define "generic-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "generic-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}