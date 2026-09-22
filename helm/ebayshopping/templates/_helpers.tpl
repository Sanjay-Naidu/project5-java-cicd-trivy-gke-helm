{{/*
=============================================================================
Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
Author  : Sanjay Naidu
File    : helm/ebayshopping/templates/_helpers.tpl - naming/label helpers
=============================================================================
*/}}

{{/* Chart name, overridable */}}
{{- define "ebayshopping.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified app name (release + chart, deduplicated) */}}
{{- define "ebayshopping.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Chart label value */}}
{{- define "ebayshopping.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Immutable image tag guard. Fails the render (and therefore the deploy)
if the tag is empty or "latest" - a moving tag makes "what is running in
prod?" unanswerable and rollbacks unreliable.
*/}}
{{- define "ebayshopping.imageTag" -}}
{{- $tag := .Values.image.tag | toString -}}
{{- if or (eq $tag "") (eq $tag "latest") -}}
{{- fail "image.tag must be an immutable tag (e.g. sha-1a2b3c4) - empty and 'latest' are not allowed" -}}
{{- end -}}
{{- $tag -}}
{{- end }}

{{/* Standard Kubernetes recommended labels */}}
{{- define "ebayshopping.labels" -}}
helm.sh/chart: {{ include "ebayshopping.chart" . }}
{{ include "ebayshopping.selectorLabels" . }}
app.kubernetes.io/version: {{ include "ebayshopping.imageTag" . | quote }}
app.kubernetes.io/part-of: ebayshopping
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels - immutable after first deploy, so kept minimal */}}
{{- define "ebayshopping.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ebayshopping.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* ServiceAccount name */}}
{{- define "ebayshopping.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ebayshopping.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
