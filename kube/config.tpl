# Rendered by `kuse <name>` (zsh/kube.zsh) through `op inject`. No secrets
# here: each secret reference resolves from the 1Password item kuse picks for
# <name> (see KUBE_CLUSTERS), which needs the fields server, ca and token. __NAME__ is
# swapped for <name> before op sees the file. A cluster that needs another
# shape (exec auth, client certs) gets its own ~/.kube/<name>.tpl instead.
apiVersion: v1
kind: Config
clusters:
- name: __NAME__
  cluster:
    server: "op://${KUBE_OP_VAULT}/${KUBE_OP_ITEM}/server"
    certificate-authority-data: "op://${KUBE_OP_VAULT}/${KUBE_OP_ITEM}/ca"
contexts:
- name: __NAME__
  context:
    cluster: __NAME__
    user: __NAME__
current-context: __NAME__
users:
- name: __NAME__
  user:
    token: "op://${KUBE_OP_VAULT}/${KUBE_OP_ITEM}/token"
