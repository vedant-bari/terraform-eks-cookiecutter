{{- define "eks-generic-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "eks-generic-app.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" .Release.Name (include "eks-generic-app.name" .) | trunc 63 | trimSuffix "-" }}{{ end }}
{{- end }}
{{- define "eks-generic-app.labels" -}}
app.kubernetes.io/name: {{ include "eks-generic-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}
{{- define "eks-generic-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eks-generic-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "eks-generic-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}{{ default (include "eks-generic-app.fullname" .) .Values.serviceAccount.name }}{{ else }}{{ required "serviceAccount.name is required when serviceAccount.create is false" .Values.serviceAccount.name }}{{ end }}
{{- end }}
{{- define "eks-generic-app.secretName" -}}
{{- default (printf "%s-env" (include "eks-generic-app.fullname" .)) .Values.externalSecret.targetSecretName }}
{{- end }}
