# BuildLight

[![Build Status](https://travis-ci.org/collectiveidea/buildlight.svg?branch=master)](https://travis-ci.org/collectiveidea/buildlight) [![CircleCI](https://circleci.com/gh/collectiveidea/buildlight.svg?style=shield)](https://circleci.com/gh/collectiveidea/buildlight) [![Heroku CI Status](https://ci-badges.herokuapp.com/pipelines/6017a3bc-5059-4539-b691-d76eceaf5e12/master.svg)](https://dashboard.heroku.com/pipelines/6017a3bc-5059-4539-b691-d76eceaf5e122/tests)

Catches webhooks from Travis CI and CircleCI and provides data to power our office stoplight.

![Collective Idea stoplight](https://buildlight.collectiveidea.com/collectiveidea.gif)

## Add Projects

### Travis CI

Simply add this to your `.travis.yml` file:

```
notifications:
  webhooks:
    urls:
      - https://buildlight.collectiveidea.com/
    on_start: always
```

### Circle CI

Simply add this to your `circle.yml` file:

```
notify:
  webhooks:
    - url: https://buildlight.collectiveidea.com
```

## Viewing Status

The [main website](https://buildlight.collectiveidea.com/) shows the basic status for all projects. Adding a user/organization name to the url shows just those projects, for example: [https://buildlight.collectiveidea.com/collectiveidea](https://buildlight.collectiveidea.com/collectiveidea)

## License

This software is © Copyright [Collective Idea](http://collectiveidea.com) and released under the MIT License.
