#!/usr/bin/env bash

kube_context="${KUBE_CONTEXT:-minikube}"

kctl() {
  kubectl --context "${kube_context}" "$@"
}
