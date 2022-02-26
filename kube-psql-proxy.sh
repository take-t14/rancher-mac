#!/bin/bash

/usr/local/bin/kubectl --kubeconfig ./kubeconfig config set-context php --namespace=postgresql
/usr/local/bin/kubectl --kubeconfig ./kubeconfig port-forward postgresql-postgresql-0 5432:5432