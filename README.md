# BuildLight

![BuildLightLogo](http://buildlight.collectiveidea.com/buildlight.png)

## Overview

Catches webhooks from Travis-CI and provides data to power our office stoplight.

## Add Projects

Simply add this to your .travis.yml file: 

```
notifications:
  webhooks:
    urls:
      - http://buildlight.collectiveidea.com/
    on_start: true
```
