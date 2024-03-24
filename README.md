# demo-web-py
This application is using a specific workflow in combination with ArgoCD and github action.

## Workflow

<p align="center">
  <img src="src/workflow.png" width="100%" height="60%">
</p>

The artefact creation workflow:
- Create artefact on PR with tags `sha-<sha1>` and `pr-<pr-number>`
- Create new artefact on PR commit `sha-<sha2>` and update `pr-<pr-number>` to the new commit
- Promote artefact `pr-<pr-number>` on merge PR

PR number can be identified from a commit on Github API with following command:
```bash
gh pr list --search <sha> --state merged --json url --jq '.[0].url'
```

<p align="center">
  <img src="src/promotion.png" width="70%" height="60%">
</p>

ArgoCD notifies Github for successful deployment:

<p align="center">
  <img src="src/notification.png" width="100%" height="60%">
</p>

To notify Github for a deployment status for a specific commit use this command:
```bash
gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/ixxeL-DevOps/demo-web-py/statuses/<sha> -f state='success' -f description='Ephemeral env deployment' -f
context='continuous-integration/argocd'
```

Curl version:
```bash
curl -L -X POST -H "Accept: application/vnd.github+json" H "Authorization: Bearer <YOUR-TOKEN>" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/ixxeL-DevOps/demo-web-py/statuses/<sha> -d '{"state":"success","description":"Ephemeral env deployment","context":"continuous-integration/argocd"}'
```

and check it:
```bash
gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/ixxeL-DevOps/demo-web-py/commits/<sha>/statuses
```
Curl version:
```bash
curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer <YOUR-TOKEN>" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/ixxeL-DevOps/demo-web-py/commits/<sha>/statuses
```

Documentation:
- https://docs.github.com/en/rest/commits/statuses?apiVersion=2022-11-28

## ArgoCD config

Documentation :
- https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/templates/


Here is the description of the ArgoCD `ApplicationSet` responsible for app creation:
```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: demo-web-preview
spec:
  generators:
    - pullRequest:
        github:
          owner: ixxeL-DevOps
          repo: demo-web-py
          tokenRef:
            key: github_token
            secretName: github-creds
        requeueAfterSeconds: 60
  template:
    metadata:
      name: 'demo-web-pr-{{number}}'
      annotations:
        notifications.argoproj.io/subscribe.on-deployed.github: ""
    spec:
      destination:
        namespace: 'demo-web-pr-{{number}}'
        name: 'vk-pprod'
      project: ephemeral
      source:
        path: deploy/
        repoURL: 'https://github.com/ixxeL-DevOps/demo-web-py.git'
        targetRevision: '{{branch}}'
        helm:
          releaseName: 'demo-web-pr-{{number}}'
          parameters:
            - name: tag
              value: 'sha-{{head_sha}}'
            - name: name
              value: 'demo-web-pr-{{number}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - Validate=true
          - PruneLast=false
          - RespectIgnoreDifferences=true
          - Replace=false
          - ApplyOutOfSyncOnly=true
          - CreateNamespace=true
          - ServerSideApply=true
      info:
      - name: url
        value: 'https://demo-web-pr-{{number}}.k8s-app.fredcorp.com/'
```

Notice the annotation for webhook callback to Github:
```yaml
annotations:
  notifications.argoproj.io/subscribe.on-deployed.github: ""
```

And here is the configuration for ArgoCD:

```yaml
secret:
  name: repo-creds-github # uses this secret to fetch the 'password' key in it (which has access to api Github for notifications)

notifiers:
  service.webhook.github: |
    url: https://api.github.com
    headers:
    - name: Authorization
      value: token $password

triggers:
  trigger.on-deployed: |
    - description: Application is synced and healthy. Triggered once per commit.
      oncePer: app.status.operationState.syncResult.revision
      send:
      - github-commit-status
      when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy' and app.status.sync.status == 'Synced'

templates:
  template.github-commit-status: |
    webhook:
      github:
        method: POST
        path: /repos/{{call .repo.FullNameByRepoURL .app.spec.source.repoURL}}/statuses/{{.app.status.operationState.operation.sync.revision}}
        body: |
          {
            {{if eq .app.status.operationState.phase "Running"}} "state": "pending"{{end}}
            {{if eq .app.status.operationState.phase "Succeeded"}} "state": "success"{{end}}
            {{if eq .app.status.operationState.phase "Error"}} "state": "error"{{end}}
            {{if eq .app.status.operationState.phase "Failed"}} "state": "error"{{end}},
            "description": "{{.app.metadata.name}} img tag: {{ (call .repo.GetAppDetails).Helm.GetParameterValueByName "tag" }}",
            "target_url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "context": "continuous-integration/argocd"
          }
```

Argocd display application information:
```bash
argocd app get argocd/demo-web-pr-5 --grpc-web --show-params --show-operation
```

result:
```
Name:               argocd/demo-web-pr-5
Project:            ephemeral
Server:             vk-pprod
Namespace:          demo-web-pr-5
URL:                https://argocd.k8s-app.fredcorp.com/applications/demo-web-pr-5
Repo:               https://github.com/ixxeL-DevOps/demo-web-py.git
Target:             feat/ephemeral4
Path:               deploy/
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to feat/ephemeral4 (d751238)
Health Status:      Healthy

Operation:          Sync
Sync Revision:      d751238e003a92968e2276456f2e0e3ac2ba7216
Phase:              Succeeded
Start:              2024-03-24 17:02:22 +0100 CET
Finished:           2024-03-24 17:02:25 +0100 CET
Duration:           3s
Message:            successfully synced (all tasks run)


NAME  VALUE
tag   sha-d751238e003a92968e2276456f2e0e3ac2ba7216
name  demo-web-pr-5

GROUP              KIND        NAMESPACE      NAME           STATUS   HEALTH   HOOK  MESSAGE
                   Namespace                  demo-web-pr-5  Running  Synced         namespace/demo-web-pr-5 serverside-applied
                   Service     demo-web-pr-5  demo-web-pr-5  Synced   Healthy        service/demo-web-pr-5 serverside-applied
apps               Deployment  demo-web-pr-5  demo-web-pr-5  Synced   Healthy        deployment.apps/demo-web-pr-5 serverside-applied
networking.k8s.io  Ingress     demo-web-pr-5  demo-web-pr-5  Synced   Healthy        ingress.networking.k8s.io/demo-web-pr-5 serverside-applied
```