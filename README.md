# Better Chef Rundeck

A Sinatra app for integrating Rundeck and Chef - a Chef search query is sent to the app at `/<key>:<search_term>` and the app will query the Chef server and return the nodes and their attributes in a format suitable for a Rundeck project's [resource model source](http://rundeck.org/docs/administration/managing-node-sources.html#resource-model-source).

# Overview

This Sinatra app allows defining a Chef node search query right in the path of an HTTP request. For example:

```
GET /role:webserver
```

will return all nodes that match the node search query `role:webserver` in a format that Rundeck can parse for a project. A Rundeck project can be configured to use this url as the resource model source in the project's `project.properties`:

```INI
resources.source.1.type=url
resources.source.1.config.url=http\://better-chef-rundeck.example.com/role:webserver
```

# Running the App

This gem is not yet production ready or available from rubygems. Until then, clone the project, and install dependencies with `bundle install`. Then run the app:

```
bundle exec bin/better-chef-rundeck
```

The app will look for a `knife.rb` or / then `client.rb` to configure its Chef server api calls by default.

Try out the app at [localhost:4567/key:search_pattern](http://localhost:4567/key:search_pattern)

# Gem Configuration

You can set logging and other stuff with command line options. Learn more about these with the `-h`, `--help` option:

```
bundle exec bin/better-chef-rundeck --help
```

## Caching

If the same Chef search is called within the specified cache seconds setting, the cached result will be returned.

# Usage in Rundeck

## Which Attributes to Return from Chef

Read [filtering Chef search returned attributes](https://docs.chef.io/chef_search.html#filter-search-results) for information about `filter_result` (originally referred to as `partial_search`).

No, I'm serious. Go read it. It's not even long.

Specify which Chef node attributes should be in the returned data (`filter_result`) using GET parameters. **If these GET parameters are not set, the normal Chef attributes will be returned (which may or may not be what is wanted, especially in a very large environment).** Specify the attribute name as the GET param and the Chef attribute path as a comma-delimited list (`some,attribute,path`, `languages,ruby,version`) as the value of the GET param. So to convert the attribute `['really']['deep']['attr']` into the attribute `short`, use the GET param `short=really,deep,attr`.

### Example `filter_result` GET parameters

Chef node:

```yaml
---
somenode:
  ipaddress: 10.11.12.13
  kernel:
    version: 7.8.9
  languages:
    ruby:
      version: 2.1.0
```

Request:

```yaml
GET /name:somenode?ip:ipaddress&kernel_version:kernel,version&ruby_version:languages,ruby,version

---
somenode:
  ip: 10.11.12.13
  kernel_version: 7.8.9
  ruby_version: 2.1.0
```

### Default `filter_result` attributes

If no attributes are specified for `filter_result`, the Chef node attributes returned will be very similar to running `knife search node QUERY`. But if any values are specified for `filter_result`, these default node attributes will not be returned; they will have to be explicitly requested in the `filter_result` GET parameters.

Chef node:

```yaml
---
anothernode:
  environment: prod
  fqdn: anothernode.example.com
  ipaddress: 100.101.102.103
  run_list: recipe[base_os], role[webserver]
  roles: webserver
  platform: redhat
  tags:
    rundeck-managed
    some-tag
```

A request without specifying `filter_result` GET params would return exactly the data above. But a request specifying only the `filter_result` GET params `ip=ipaddress` and `ruby_version=languages,ruby,version` will not get all the attributes back because the request did not specify them:

```yaml
GET /name:anothernode?ip:ipaddress&ruby_version:languages,ruby,version

---
anothernode:
  ip: 100.101.102.103
  ruby_version: 2.2.3
```

## `default_`ing and `override_`ing Attributes

Set GET parameters to default and override node attributes. Set the GET parameter `default_<attr>=<value>` to default `<attr>` to `<value>` (defaults if the attribute value is `nil` or the attribute is not set for the node). Similarly, set the GET parameter `override_<attr>=<value>` to set `<attr>` to `<value>` for *all* nodes returned.

A common use case for `default_` or `override_` attributes is setting the attribute `username` to the value `${option.username}` for usage in remote ssh logins in a Rundeck job as a job option.

To illustrate this, three Chef nodes with different attributes (some attributes unset, some `nil`):

```yaml
---
nodea:
  domain: example.com
  ruby_version: 2.1.0
nodeb:
  domain: different.co
  ruby_version:
  username: rundeck_svc_acct
nodec:
  domain:
  ruby_version:
```

This request would return something similar to the following:

```yaml
GET /*:*?default_domain=github.com&override_ruby_version=2.2.0&default_username=${option.username}

---
nodea:
  domain: example.com
  ruby_version: 2.2.0
  username: ${option.username}
nodeb:
  domain: different.co
  ruby_version: 2.2.0
  username: rundeck_svc_acct
nodec:
  domain: github.com
  ruby_version: 2.2.0
  username: ${option.username}
```

# Improvements from the `chef-rundeck` Gem

The biggest issue with oswaldlabs/chef-rundeck is that project node searches are defined in a config file (`/etc/chef/rundeck.json`), and to update a project's node search requires updating that config file and restarting `chef-rundeck`. Defining a Rundeck project's Chef node search query in a configuration file separate from the rest of the Rundeck project configuration (`project.properties`) doesn't make sense. `better-chef-rundeck` allows updating a Rundeck project's node search by simply updating the resource model source url.
