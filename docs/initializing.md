# Initializing CommandTower

Blah Blah Lazy....

Check out the Rails Generator.
```
rails g command_tower:configure
```

The Generator will:

## Add Configuration file
The configuration file will get generated in `config/initializers/command_tower.rb`. This file will contain a list of every config option that you can change. Additionally, it will provide details about what each configuration option does so you are not fumbling around.

Check out the [Rails App Config file for an example](/rails_app/config/initializers/command_tower.rb)

## Mounts the engine as a route

To properly utilize this engine, it needs to get mounted in your applications route file. This will do it for you. Feel free to change the default path if desired


## Create DB migrations
@matt-taylor to complete

