{{/*
Expand the name of the chart.
*/}}
{{- define "eks-test-app.fullname" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
