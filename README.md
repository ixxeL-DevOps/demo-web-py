# demo-web-py
This application is using a specific workflow in combination with ArgoCD and github action.

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
            "description": "Application {{.app.metadata.name}} sha {{.app.status.operationState.operation.sync.revision}} status {{.app.status.operationState.phase}}",
            "target_url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
            "context": "continuous-integration/argocd"
          }
```