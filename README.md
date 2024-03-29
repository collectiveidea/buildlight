# BuildLight

[![Github Actions](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml/badge.svg)](https://github.com/collectiveidea/buildlight/actions/workflows/ci.yml)[![Build Status](https://travis-ci.org/collectiveidea/buildlight.svg?branch=master)](https://travis-ci.org/collectiveidea/buildlight) [![CircleCI](https://circleci.com/gh/collectiveidea/buildlight.svg?style=shield)](https://circleci.com/gh/collectiveidea/buildlight) [![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

Catches webhooks from build services (GitHub Actions, Travis CI, Circle CI, etc.) and provides data to power our office stoplight.

![Collective Idea stoplight](https://buildlight.collectiveidea.com/collectiveidea.gif)

## Add Projects

### GitHub Actions

We assume you have one or more GitHub Action workflow(s) you use. You'll need their `name` below in the `workflows` section.

Copy this to `.github/workflows/buildlight.yml` :

```yaml
name: Buildlight

on:
  workflow_run:
    workflows: [Run Tests] # Replace with your GitHub Action's name(s)
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

Go to your project settings in Circle CI and add a new Webhook with `https://buildlight.collectiveidea.com` as the Receiver URL. Ensure the the "Workflow Completed" event is checked.

## Viewing Status

The [main website](https://buildlight.collectiveidea.com/) shows the basic status for all projects. Adding a user/organization name to the url shows just those projects, for example: [https://buildlight.collectiveidea.com/collectiveidea](https://buildlight.collectiveidea.com/collectiveidea). 

Devices (editable only manually for now) can aggregate multiple organizations & projects, and have their own URL. For example, our office's physical light (see gif above) aggregates [@collectiveidea](https://github.com/collectiveidea), [@deadmanssnitch](https://github.com/deadmanssnitch), and client projects. Its URL is: https://buildlight.collectiveidea.com/devices/collectiveidea-office

## License

This software is © Copyright [Collective Idea](http://collectiveidea.com) and released under the MIT License.
