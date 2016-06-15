# BuildLight

Catches webhooks from Travis-CI and provides data to power our office stoplight.

![Collective Idea stoplight](https://buildlight.collectiveidea.com/collectiveidea.gif)

## Add Projects

Simply add this to your `.travis.yml` file:

```
notifications:
  webhooks:
    urls:
      - http://buildlight.collectiveidea.com/
    on_start: always
```

## Viewing Status

The [main website](https://buildlight.collectiveidea.com/) shows the basic status for all projects. Adding a user/organization name to the url shows just those projects, for example: [https://buildlight.collectiveidea.com/collectiveidea](https://buildlight.collectiveidea.com/collectiveidea)  

## License

This software is © Copyright [Collective Idea](http://collectiveidea.com) and released under the MIT License.
