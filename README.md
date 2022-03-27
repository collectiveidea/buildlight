# BuildLight

[![Github Actions](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml/badge.svg)](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml)[![Build Status](https://travis-ci.org/collectiveidea/buildlight.svg?branch=master)](https://travis-ci.org/collectiveidea/buildlight) [![CircleCI](https://circleci.com/gh/collectiveidea/buildlight.svg?style=shield)](https://circleci.com/gh/collectiveidea/buildlight) [![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

Catches webhooks from build services (GitHub Actions, Travis CI, Circle CI, etc.) and provides data to power our office stoplight.

![Collective Idea stoplight](https://buildlight.collectiveidea.com/collectiveidea.gif)

## Add Projects

### GitHub Actions

We assume you have a primary GitHub action workflow you use. You'll need its `name` below.

Copy this to `.github/workflows/buildlight.yml` :

```yaml
name: Buildlight

on:
  workflow_run:
    workflows: [Run Tests] # Replace with what your GitHub Action's name is
    branches: [main] # Your default branch.

jobs:
  buildlight:
    runs-on: ubuntu-latest
    steps:
      - uses: collectiveidea/buildlight@main
```

### Travis CI

Simply add this to your `.travis.yml` file:

```yaml
notifications:
  webhooks:
    urls:
      - https://buildlight.collectiveidea.com/
    on_start: always
```

### Circle CI

Simply add this to your `.circle/config.yml` file:

```
notify:
  webhooks:
    - url: https://buildlight.collectiveidea.com
```

## Viewing Status

The [main website](https://buildlight.collectiveidea.com/) shows the basic status for all projects. Adding a user/organization name to the url shows just those projects, for example: [https://buildlight.collectiveidea.com/collectiveidea](https://buildlight.collectiveidea.com/collectiveidea)

## License

This software is © Copyright [Collective Idea](http://collectiveidea.com) and released under the MIT License.
