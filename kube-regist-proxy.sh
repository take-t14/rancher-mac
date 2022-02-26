#!/bin/bash

/usr/local/bin/kubectl --kubeconfig ./kubeconfig config set-context php --namespace=gitlab-ce
/usr/local/bin/kubectl --kubeconfig ./kubeconfig port-forward gitlab-ce-gitlab-ce-0 4567:4567