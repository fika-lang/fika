<img src="https://github.com/fika-lang/assets/blob/master/logo.png?raw=true" width="150"/>

[![FOSSUnited](http://fossunited.org/files/fossunited-badge.svg)](https://fossunited.org/) &nbsp;&nbsp;
[![Discord](https://img.shields.io/discord/756840900952588321?color=7389D8&label=Discord&logo=discord&logoColor=white&style=plastic)](https://discord.gg/zNs6Gs5)

-----

Fika is a modern programming language for the web.
It is statically typed, functional and runs on the BEAM (Erlang VM).

Project status: Actively developed. Not ready for production use or HackerNews.
Currently, Fika is an early prototype and hence has many hacky implementations.

If you'd like to keep tabs on our progress, please [subscribe to our updates here](https://tinyletter.com/fika).

### Syntax

Here's a quick walkthrough of Fika's syntax: [example.fi](https://github.com/fika-lang/fika/blob/main/example.fi)

### Running Fika programs

Fika is written in Elixir, so make sure you have that installed.
Follow [these instructions](https://elixir-lang.org/install.html) to install
Elixir. Next, clone this repo, cd into the directory and then follow the below instructions.

#### Using Elixir shell

```
# Install dependencies and run the Elixir shell
mix deps.get
iex -S mix

# In the Elixir shell, compile and load a Fika file using the following:
> Fika.Code.load_module("example")

# Now you can run functions from the module like this:
> :example.sum(40, 2)
> 42
```

#### Using `fika` executable

```
# Create the executable
mix release

# The above command creates an executable in the path ./_build/prod/rel/bakeware/fika
# Call the function example.sum(1, 2) from the file example.fi
./_build/prod/rel/bakeware/fika exec --function="foo()" example
```

PS: If you're developing Fika, the recommended way to try Fika code is to use
the Elixir shell which is documented above because this is faster.


### Your first HTTP server

Fika comes with a web server which allows you to quickly create HTTP request
handlers. Note: This web server is a prototype currently and only responds with
strings and a 200 status code.

```elixir
# Inside examples/router.fi

fn routes : List({method: String, path: String, handler: Fn(->String)}) do
  [
    {method: "GET", path: "/", handler: &hello},
    {method: "GET", path: "/foo", handler: &bar}
  ]
end

fn hello : String do
  "Hello world"
end

fn bar : String do
  "Bar"
end
```

Now start the webserver in one of two ways:

#### Using Elixir shell

```
iex -S mix
# A web server is started automatically using the router `examples/router.fi`
```

#### Using `fika` executable

```
# Create the executable
mix release

# router.fi is in the `examples` folder
cd examples
../_build/prod/rel/bakeware/fika
```

Now open `http://localhost:9090` in the browser to see "Hello world" served
by Fika. Changes to the router are picked up automatically.

### Fika together!

If you'd like to be part of the Fika community, you can find us here:

[![Discord server](https://github.com/fika-lang/assets/blob/master/discord_server.png?raw=true)](https://discord.gg/zNs6Gs5)  
This is the best place to chat with Fika developers, ask questions or get guidance
on contributing to Fika. We also livestream some talks and pair programming sessions here.
[Here's the link to join.](https://discord.gg/zNs6Gs5)

[![Hackers list](https://github.com/fika-lang/assets/blob/master/hackers_list.png?raw=true)](https://tinyletter.com/fika)  
This is an email digest where we send out the latest updates
about Fika and our ecosystem. [Here's the link to subscribe.](https://tinyletter.com/fika)

If you'd like to contact the creator of Fika, you can find Emil Soman on
[twitter](https://twitter.com/emilsoman) or drop a mail to `fikalanguage@gmail.com`.


### Thanks

Fika's development is supported by its many contributors and [the grant from
FOSSUnited](https://forum.fossunited.org/t/foss-hack-2020-results/424). Thank you!
