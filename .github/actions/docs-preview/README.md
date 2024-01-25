## About

GitHub Action to create a GitHub comment with the docs-preview

* [Usage](#usage)
  * [Configuration](#configuration)
* [Customizing](#customizing)
  * [inputs](#inputs)

## Usage

### Configuration

Given the CI GitHub action:

```yaml
---
on:
  pull_request_target:
    types: [opened]

permissions:
  pull-requests: write

jobs:
  doc-preview:
    runs-on: ubuntu-latest
    steps:
      - uses: elastic/docs/.github/actions/docs-preview@current
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          repo: ${{ github.event.repository.name }}
          preview-path: 'guide/en/observability/master/index.html'
          pr: ${{ github.event.pull_request.number }}
          
```

## Customizing

### inputs

Following inputs can be used as `step.with` keys

| Name              | Type    | Description                                    |
|-------------------|---------|------------------------------------------------|
| `preview-path`    | String  | Path to append to base doc url in preview link |
| `repo`            | String  | The GitHub repository name without org         |
| `github-token`    | String  | The GitHub token                               |
| `pr`              | String  | The GitHub PR number                           |
