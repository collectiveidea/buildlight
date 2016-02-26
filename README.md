# BuildLight

![BuildLightLogo](http://buildlight.collectiveidea.com/buildlight.png)

## Overview

Catches webhooks from Travis-CI and provides data to power our office stoplight.

![Collective Idea stoplight](http://buildlight.collectiveidea.com/collectiveidea.gif)

## Add Projects

Simply add this to your .travis.yml file:

```
notifications:
  webhooks:
    urls:
      - http://buildlight.collectiveidea.com/
    on_start: always
```