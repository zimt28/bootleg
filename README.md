# Bootleg

[![CircleCI](https://img.shields.io/circleci/project/github/labzero/bootleg/master.svg)](https://circleci.com/gh/labzero/bootleg) [![Hex.pm](https://img.shields.io/hexpm/v/bootleg.svg)](https://hex.pm/packages/bootleg) [![Packagist](https://img.shields.io/packagist/l/doctrine/orm.svg)](https://github.com/labzero/bootleg/blob/master/LICENSE)

Simple deployment and server automation for Elixir.

**Bootleg** is a simple set of commands that attempt to simplify building and deploying elixir applications. The goal of the project is to provide an extensible framework that can support many different deploy scenarios with one common set of commands.

Out of the box, Bootleg provides remote build and remote server automation for your existing [Distillery](https://github.com/bitwalker/distillery) releases. Bootleg assumes your project is committed into a `git` repository and some of the build steps use this assumption
to handle code in some steps of the build process. If you are using an scm other than git, please consider contributing to Bootleg to
add additional support.

## Installation

```elixir
def deps do
  [{:distillery, "~> 1.3",
   {:bootleg, "~> 0.3"}]
end
```

## Build server setup

In order to build your project, Bootleg requires that your build server be set up to compile
Elixir code. Make sure you have already installed Elixir on any build server you define. The remote


## Quick Start

### Initialize your project

This step is optional but if run will create an example `config/deploy.exs` file that you
can use as a starting point.

```sh
$ mix bootleg.init
```

### Configure your release parameters

```elixir
# config/deploy.exs
use Bootleg.Config

role :build, "your-build-server.local", user: "develop", password: "bu1ldm3", workspace "/some/build/workspace"
role :app, ["web1", "web2", "web3"], user: "admin", password: "d3pl0y", workspace "/var/myapp"
```

### build and deploy

```sh
$ mix bootleg.build
$ mix bootleg.deploy
$ mix bootleg.start
```

also see: [Phoenix support](#phoenix-support)

## Configuration

Create and configure Bootleg's `config/deploy.exs` file:

```elixir
# config/deploy.exs
use Bootleg.Config

role :build, "build.example.com", user, "build", port: "2222", workspace: "/tmp/build/myapp"
role :app, ["web1.example.com", "web2.myapp.com"], user: "admin", workspace: "/var/www/myapp"
```

## Roles

Actions in Bootleg are paired with roles, which are simply a collection of hosts that are responsible for the same function, for example building a release, archiving a release, or executing commands against a running application.

Role names are unique so there can only be one of each defined, but hosts can be grouped into one or more roles. Roles can be declared repeatedly to provide a different set of options to different sets of hosts.

By defining roles, you are defining responsibility groups to cross cut your host infrastructure. The `build` and
`app` roles have inherent meaning to the default behavior of Bootleg, but you may also define more that you can later filter on when running commands inside a Bootleg hook. There is another built in role `:all` which will always include
all hosts assigned to any role. `:all` is only available via `remote/2`.

Some features or extensions may require additional roles, for example if your
release needs to run Ecto migrations, you will need to assign the `:db`
role to one host.

### Role and host options

Options are set on roles and on hosts based on the order in which the roles are defined. Some are used internally
by Bootleg:

  * `workspace` - remote path specifying where to perform a build or push a deploy (default `.`)
  * `user` - ssh username (default to local user)
  * `password` - ssh password
  * `identity` - file path of an SSH private key identify file
  * `port` - ssh port (default `22`)

#### Examples

```elixir
role :app, ["host1", "host2"], user: "deploy", identity: "/home/deploy/.ssh/deploy_key.priv"
role :app, ["host2"], port: 2222
```
> In this example, two hosts are declared for the `app` role, both as the user *deploy* but only *host2* will use the non-default port of *2222*.

```elixir
role :db, ["db.example.com", "db2.example.com"], user: "datadog"
role :db, "db.example.com", primary: true
```
> In this example, two hosts are declared for the `db` role but the first will receive a host-specific option for being the primary. Host options can be arbitrarily named and targeted by tasks.

```elixir
role :balancer, ["lb1.example.com", "lb2.example.com"], banana: "boat"
role :balancer, "lb3.example.com"
```
> In this example, two load balancers are configured with a host-specific option of *banana*. The `balancer` role itself also receives the role-specific option of *banana*. A third balancer is then configured without any specific host options.


#### SSH options

If you include any common `:ssh.connect` options they will not be included in role or host options and will only be used when establishing SSH connections (exception: *user* is always passed to role and hosts due to its relevance to source code management).

Supported SSH options include:

* user
* port
* timeout
* recv_timeout

> Refer to `Bootleg.SSH.supported_options/0` for the complete list of supported options, and [:ssh.connect](http://erlang.org/doc/man/ssh.html#connect-2) for more information.

### Role restrictions

Bootleg extensions may impose restrictions on certain roles, such as restricting them to a certain number of hosts. See the extension documentation for more information.

### Roles provided by Bootleg

* `build` - Takes only one host. If a list is given, only the first hosts is
used and a warning may result. If this role isn't set the release packaging will be done locally.
* `app` -  Takes a lists of hosts, or a string with one host.

## Building and deploying a release

```console
mix bootleg.build production
mix bootleg.deploy production
mix bootleg.start production
```

Alternatively the above commands can be rolled into one with:

```console
mix bootleg.update production
```

Note that `bootleg.update` will stop any running nodes and then perform a cold start. The stop is performed with
the task `stop_silent`, which differs from `stop` in that it does not fail if the node is already stopped.

`bootleg.build` will clean the remote workspace prior to copying the code over, to ensure that any files left from
a previous build do not cause issues. The entire contents of the remote workspace are removed via `rm -rf *` from
the root of the workspace. You can configure this behavior by setting the config option `clean_locations`, which
takes a list of locations and passes them to `rm -rf` on the remote server. Relative paths will be interpreted relative
to the workspace, absolute paths will be treated as is. This does mean that `config :clean_locations, ["/"]` will
try and erase the entire root file system of your remote server. Be careful when altering `clean_locations` and never
use a priviallaged user on your build server.

## Admin Commands

Bootleg has a set of commands to check up on your running nodes:

```console
mix bootleg.restart production  # Restarts a deployed release.
mix bootleg.start production      # Starts a deployed release.
mix bootleg.stop production      # Stops a deployed release.
mix bootleg.ping production      # Check status of running nodes
```

## Other Comamnds

Bootleg has a few utility commands to help streamline its usage:

```console
mix bootleg.init             # Initializes a project for use with Bootleg
mix bootleg.invoke <task>    # Calls an arbitrary Bootleg task
```

## Hooks

Hooks may be defined by the user in order to perform additional (or exceptional)
operations before or after certain actions performed by Bootleg.

Hooks are defined within `config/deploy.exs`. Hooks may be defined to trigger
before or after a task. The following tasks are provided by Bootleg:

1. `build` - build process for creating a release package
  1. `clean` - cleans the remote workspace
  2. `compile` - compilation of your project
  3. `generate_release` - generation of the release package
2. `deploy` - deploy of a release package
3. `start` - starting of a release
4. `stop` - stopping of a release
5. `restart` - restarting of a release
6. `ping` - check connectivity to a deployed app

Hooks can be defined for any task (built-in or user defined), even ones that do not exist. This can be used
to create an "event" that you want to respond to, but has no real "implementation".

To register a hook, use:

 * `before_task <:task> do ... end` - Before `task` executes, execute the provided code block.
 * `after_task <:task> do ... end` - After `task` executes, execute the provided code block.

For example:

```elixir
use Bootleg.Config

before_task :build do
  IO.puts "Starting build..."
end

after_task :deploy do
  MyAPM.notify_deploy()
end
```

You can define multiple hooks for a task, and they will be executed in the order they are defined. For example:

```elixir
use Bootleg.Config

before_task :start do
  IO.puts "This may take a bit"
end

after_task :start do
  IO.puts "Started app!"
end

before_task :start do
  IO.puts "Starting app!"
end
```

would result in:

```
$ mix bootleg.build
This may take a bit
Starting app!
...
Started app!
$
```

## `invoke` and `task`

There are a few ways for custom code to be executed during the Bootleg life
cycle. Before showing some examples, here's a quick glossary of the related
pieces.

 * `task <:identifier> do ... end` - Assign a block of code to the atom provided as `:identifier`.
   This can then be executed by using the `invoke` macro.
 * `invoke <:identifier>` - Execute the `task` code blocked identified by `:identifier`, as well as
   any before/after hooks.

**NOTE:** Invoking an undefined task is not an error and any registered hooks will still be executed.

```elixir
use Bootleg.Config

before_task :build do
  IO.puts "Hello"
  invoke :custom_event
end

task :custom_task do
  IO.puts "World"
end

after_task :custom_event do
  IO.puts "Elixir"
  invoke :custom_task
end
```

A shortened `before`/`after` syntax can be used to simply invoke a task directly from an event.

```elixir
task :clear_cache do
  {:ok, _} = remote do
    "rm -rf /tmp/cache"
  end
end

before_task :restart, do: :clear_cache
```

Alternatively:

```elixir
before_task :restart do
  {:ok, _output} = remote do
    "rm -rf /tmp/cache"
  end
end
```

## `remote`

The workhorse of the Bootleg DSL is `remote`: it executes shell commands on remote servers and returns
the results. It takes a role and a block of commands to execute. The commands are executed on all servers
belonging to the role, and raises an `SSHError` if an error is encountered. Optionally, a list of options
can be provided to filter the hosts where the commands are run.

```elixir
use Bootleg.Config

# basic
remote :app do
  "echo hello"
end

# multi line
remote :app do
  "touch ~/file.txt"
  "rm file.txt"
end

# getting the result
[{:ok, [stdout: output], _, _}] = remote :app do
  "ls -la"
end

# raises an SSHError
remote :app do
  "false"
end

# filtering - only runs on app hosts with an option of primary set to true
remote :app, primary: true do
  "mix ecto.migrate"
end
```

## Phoenix Support

Bootleg builds elixir apps, if your application has extra steps required make use of the hooks
system to add additional functionality. A common case is for building assets for Phoenix
applications. To build phoenix assets during your build, include the additional package
`bootleg_phoenix` to your `deps` list. This will automatically perform the additional steps required
for building phoenix releases.

```elixir
# mix.exs
def deps do
  [{:distillery, "~> 1.3"},
  {:bootleg, "~> 0.3"},
  {:bootleg_phoenix, "~> 0.1"}]
end
```

For more about `bootleg_phoenix` see: https://github.com/labzero/bootleg_phoenix

## Sharing Tasks

Sharing is a good thing. We love to share, espically awesome code we write. Bootleg supports loading
tasks from packages in a manner very similar to `Mix.Task`. Just define your module under `Bootleg.Tasks`,
`use Bootleg.Task` and pass it a block of Bootleg DSL. The contents will be discovered and executed
automatically at launch.

```elixir
defmodule Bootleg.Tasks.Foo do
  use Bootleg.Task do
    task :foo do
      IO.puts "Foo!!"
    end

    before_task :build, :foo
  end
end
```

See `Bootleg.Task` for more details.

## Help

If something goes wrong, retry with the `--verbose` option.
For detailed information about the Bootleg commands and their options, try `mix bootleg help <command>`.

-----

## Acknowledgments

Bootleg makes heavy use of the [bitcrowd/SSHKit.ex](https://github.com/bitcrowd/sshkit.ex)
library under the hood. We would like to acknowledge the effort from the bitcrowd team that went into
creating SSHKit.ex as well as for them prioritizing our requests and providing a chance to collaborate
on ideas for both the SSHKit.ex and Bootleg projects.

## Contributing

We welcome everyone to contribute to Bootleg and help us tackle existing issues!

Use the [issue tracker][issues] for bug reports or feature requests.
Open a [pull request][pulls] when you are ready to contribute.

If you are planning to contribute documentation, please check
[the best practices for writing documentation][writing-docs].


## LICENSE

Bootleg source code is released under the MIT License.
Check the [LICENSE](LICENSE) file for more information.

  [issues]: https://github.com/labzero/bootleg/issues
  [pulls]: https://github.com/labzero/bootleg/pulls
  [writing-docs]: http://elixir-lang.org/docs/stable/elixir/writing-documentation.html



