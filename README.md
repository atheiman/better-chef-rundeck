# Better Chef Rundeck

A Sinatra app for integrating Chef and Rundeck - a Chef search query is sent as an HTTP GET request to the app at the path `/<key>:<search_term>` and the app will query the Chef server and return the nodes and their attributes in a format suitable for a Rundeck project's [resource model source](http://rundeck.org/docs/administration/managing-node-sources.html#resource-model-source).

# Overview

This app allows defining a Chef node search query right in the path of an HTTP request. For example:

```
GET /role:webserver
```

will return all nodes that match the node search query `role:webserver` in a format that Rundeck can parse for a project. A Rundeck project can be configured to use this url as the resource model source in the project's `project.properties`:

```INI
resources.source.1.type=url
resources.source.1.config.url=http\://better-chef-rundeck.example.com/role:webserver
```

## Improvements from the `chef-rundeck` Gem

The biggest issue with [oswaldlabs/chef-rundeck](https://github.com/oswaldlabs/chef-rundeck) is that project node searches are defined in a config file (`/etc/chef/rundeck.json`), and to update a project's node search requires updating that config file and restarting `chef-rundeck`. Defining a Rundeck project's Chef node search query in a configuration file separate from the rest of the Rundeck project configuration (`project.properties`) doesn't make sense. `better-chef-rundeck` allows updating a Rundeck project's node search by simply updating the resource model source url.

# Running the App

## Local Development

This gem is not yet production ready or available from rubygems. Until then, clone the project, and install dependencies with `bundle install`. Then run the app for local devlopment:

```
bundle exec rackup
```

The app will look for a `knife.rb` or / then `client.rb` to configure its Chef server api calls by default.

Try out the app at [localhost:9292](http://localhost:9292/).

Optionally, configure a few things specific to the app using environment variables - these are defined a bit further down. You can also specify web server-type config options with `rackup` arguments, run `bundle exec rackup --help` to learn more about these.

The app can also be run locally with Passenger standalone like it would be run in production:

```
bundle exec passenger start
```

## In Production

This app can easily be run with [Passenger standalone](https://www.phusionpassenger.com/library/config/standalone/intro.html). Passenger's standalone server is reliable enough to run an internal only app that handles a small amount of traffic. The basic steps are:

1. Clone the app from [the GitHub repo](https://github.com/atheiman/better-chef-rundeck)
1. Install dependencies with `bundle install --deployment --without development test`
1. Run the app: `bundle exec passenger start --environment production`

Additionally, configure the app with a `Passengerfile.json` or `passenger`'s command line arguments. [Here is a reference for those config options](https://www.phusionpassenger.com/library/config/standalone/reference/). In addition to common web server-type config options, there are config options specific to this app that can be configured with environment variables. These can be set in the shell of the user running the app with `export ENVVAR=VALUE`, or with [passenger command line args or `Passengerfile.json`](https://www.phusionpassenger.com/library/config/standalone/reference/#--envvar-envvars). These options are described below:

## Configuration

The app is configured with shell environment variables. These env vars are namespaced to not be overwritten by other programs. It should be clear that the app will run fine with the default configuration, and setting any of these env vars is not required.

Environment Variable | Explanation | Default Value
-------------------- | ----------- | -------------
`BCR_CACHE_DIR` | Chef search results are stored in this directory for cached responses | `/tmp/better-chef-rundeck-cache`
`BCR_CACHE_TIME` | Cached responses are stored for this many seconds | `30`
`BCR_CHEF_CONFIG` | Path to a Chef config file | First that exists in `['~/.chef/knife.rb', '/etc/chef/client.rb']`

## Caching

If the same Chef search is called within the specified cache seconds setting, the cached result will be returned.

# Using the API

## Which Attributes to Return from Chef

Read [filtering Chef search returned attributes](https://docs.chef.io/chef_search.html#filter-search-results) for information about `filter_result` (sometimes referred to as `partial_search`).

Seriously, go read it. It's not even long and it will make understanding this next bit *much* easier.

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
# GET /name:somenode?ip=ipaddress&kernel_version=kernel,version&ruby_version=languages,ruby,version

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
# GET /name:anothernode?ip=ipaddress&ruby_version=languages,ruby,version

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
# GET /*:*?default_domain=github.com&override_ruby_version=2.2.0&default_username=${option.username}

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

# Contributing

1. Fork the repo in GitHub
1. Create a branch (with a logical name like `feat/x` or `fix/y`)
1. Make your changes (and add applicable tests)
1. Create a pull request

# Testing

Tested with [`rspec`](http://rspec.info/) and [`chef-zero`](https://github.com/chef/chef-zero). You can execute the tests with:

```shell
$ bundle
$ bundle exec rspec
```
