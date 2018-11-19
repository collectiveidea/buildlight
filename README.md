# BuildLight

[![Build Status](https://travis-ci.org/collectiveidea/buildlight.svg?branch=master)](https://travis-ci.org/collectiveidea/buildlight) [![CircleCI](https://circleci.com/gh/collectiveidea/buildlight.svg?style=shield)](https://circleci.com/gh/collectiveidea/buildlight) [![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

Catches webhooks from Travis CI and other build services and provides data to power our office stoplight.

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

*Note:* Webhooks aren't officially supported with the 2.0 platform yet. Some people report it working.

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
