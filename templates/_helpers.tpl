{{- define "docuseal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "docuseal.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "docuseal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "docuseal.labels" -}}
helm.sh/chart: {{ include "docuseal.chart" . }}
{{ include "docuseal.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "docuseal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "docuseal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "docuseal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "docuseal.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "docuseal.secretName" -}}
{{- default (printf "%s-secrets" (include "docuseal.fullname" .)) .Values.secret.name -}}
{{- end -}}

{{- define "docuseal.serviceName" -}}
{{- include "docuseal.fullname" . -}}
{{- end -}}

{{- define "docuseal.envValueOrSecret" -}}
{{- $name := .name -}}
{{- $value := default "" .value -}}
{{- $secret := default (dict) .secret -}}
{{- if $value }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- else if $secret.enabled }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ $secret.name | quote }}
      key: {{ $secret.key | quote }}
{{- end }}
{{- end -}}
