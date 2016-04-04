# Better Chef Rundeck

A Sinatra app for integrating Rundeck and Chef - a Chef search query is sent to the app at `/<key>:<search_term>` and the app will query the Chef server and return the nodes and their attributes in a format suitable for a Rundeck project's [resource model source](http://rundeck.org/docs/administration/managing-node-sources.html#resource-model-source).

# Overview

This Sinatra app allows you to define the Chef node search query right in the path of your HTTP request. For example:

```
GET /role:webserver
```

will return all nodes that match the node search query `role:webserver` in a format that Rundeck can parse for a project. A Rundeck project can be configured to use this url as the resource model source in the project's `project.properties`:

```INI
resources.source.1.type=url
resources.source.1.config.url=http\://better-chef-rundeck.example.com/role:webserver
```

# Running the App

This gem is not yet production ready or available from rubygems, but if you want to use it you can clone the project, and install dependencies with `bundle install`. Then run the app:

```
bundle exec bin/better-chef-rundeck
```

The app will look for a `knife.rb` or / then `client.rb` to configure its Chef server api calls by default.

Try out the app at [localhost:4567/key:search_pattern]

# Gem Configuration

You can set logging and other stuff with command line options. Learn more about these with the `-h`, `--help` option.

Caching is enabled by default - if the same Chef search is called within 30 seconds, the cached result will be returned.

# Usage in Rundeck

## What Attributes to Return from Chef

First read [filtering Chef search returned attributes](https://docs.chef.io/chef_search.html#filter-search-results) if you're not familiar with `filter_result` (or the older `partial_search`).

No, I'm serious. Go read it. It's not even long.

You can specify what attributes in the returned data should point to in the Chef node attributes using GET parameters. **If you dont set these GET parameters, all attributes will be returned (which is probably not what you want).** Specify the attribute name as the GET param and the Chef attribute path as a comma-delimited list as the value of the GET param. So to convert the attribute `['really']['deep']['attr']` into the attribute `short`, use the GET param `short=really,deep,attr`.

### An Example

Chef node:

```yaml
nodea:
  ipaddress: 10.11.12.13
  kernel:
    version: 7.8.9
  languages:
    ruby:
      version 2.1.0
```

Request:

```
GET /name:nodea?ip:ipaddress&kernel_version:kernel,version&ruby_version:languages,ruby,version

nodea:
  ip: 10.11.12.13
  kernel_version: 7.8.9
  ruby_version: 2.1.0
```

## `default_`ing and `override_`ing Attributes

In addition to the Chef search set in the path of the request to `better-chef-rundeck`, you can set GET parameters to default and override node attributes. Set the GET parameter `default_<attr>=<value>` to default `<attr>` to `<value>`. Similarly, set the GET parameter `override_<attr>=<value>` to set `<attr>` to `<value>` for *all* nodes returned. To illustrate this, imagine you have three Chef nodes with different attributes (some attributes unset):

```yaml
nodea:
  domain: example.com
  ruby_version: 2.1.0
nodeb:
  domain: different.co
  ruby_version:
nodec:
  domain:
  ruby_version:
```

This request would return the following:

```
GET /*:*?default_domain=github.com&override_ruby_version=2.2.0

nodea:
  domain: example.com
  ruby_version: 2.2.0
nodeb:
  domain: different.co
  ruby_version: 2.2.0
nodec:
  domain: github.com
  ruby_version: 2.2.0
```

# Improvements from the `chef-rundeck` gem

The biggest issue with oswaldlabs/chef-rundeck is that project node searches are defined in a config file (`/etc/chef/rundeck.json`), and to update a project's node search you have to update that config file and restart `chef-rundeck`. Defining a Rundeck project's Chef node search query in a configuration file separate from the rest of the Rundeck project configuration (`project.properties`) doesn't make sense. `better-chef-rundeck` allows you to update a Rundeck project's node search by simply updating the resource model source url.
