# Better Chef Rundeck

A Sinatra app for integrating Rundeck and Chef.

# Overview

This Sinatra app allows you to define the chef node search query right in your request. For example:

```
GET /role:webserver
```

will return all nodes that match the node search query `role:webserver` in a format that Rundeck can parse for a project. A Rundeck project's `project.properties` file can be configured to use this url as the [resource model source](http://rundeck.org/docs/administration/managing-node-sources.html#resource-model-source):

```
resources.source.1.type=url
resources.source.1.config.url=http\://better-chef-rundeck.example.com/role:webserver
```

# Running the App

This gem is not yet production ready or available from rubygems, but if you want to use it you can clone the project and install dependencies with `bundle install`. Then run the app:

```
bundle exec ruby better_chef_rundeck.rb
```

The app will use a `client.rb` or `knife.rb` to configure itself by default (done by `Chef::Search::Query`)

Try out the app at [localhost:4567/key:search_pattern]

# Gem Configuration

You can set logging and other stuff for the gem in a config file. Whatever.

# Usage in Rundeck

All configuration of how a Rundeck project consumes this resource model source is set in the `project.resources.url` project property. Below are some things you can change in your url to make the returned chef node list formatted differently to be consumed by your Rundeck project.

# Improvements from the `chef-rundeck` gem

The biggest issue with oswaldlabs/chef-rundeck is that project node searches are defined in data bags, and to update a project's node search you have to update a databag and run `chef-client` on the `chef-rundeck` server. Defining a Rundeck project's chef node search query in a data bag separate from the rest of the Rundeck project configuration (`project.properties`) doesn't make sense.
