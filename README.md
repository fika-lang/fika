<img src="https://github.com/fika-lang/assets/blob/master/logo.png?raw=true" width="150"/>

[![FOSSUnited](http://fossunited.org/files/fossunited-badge.svg)](https://fossunited.org/) &nbsp;&nbsp;
[![Discord](https://img.shields.io/discord/756840900952588321?color=7389D8&label=Discord&logo=discord&logoColor=white&style=plastic)](https://discord.gg/zNs6Gs5)

-----

Fika is a modern programming language for the web.
It is statically typed, functional and runs on the BEAM (Erlang VM).

Project status: Actively developed. Not ready for production use or HackerNews.

If you'd like to keep tabs on our progress, please [subscribe to our updates here](https://tinyletter.com/fika).

### Syntax

Here's a quick walkthrough of Fika's syntax.

#### Functions

A function in Fika looks like this:

```elixir
# example.fi
fn sum(a: Int, b: Int) : Int do
  a + b
end
```

This is a function named `sum` which takes two integers and returns another integer.
Identifiers in Fika are written in snake_case (similar to Ruby, Elixir or Python).
Types are written in CamelCase.

Fika has a type checker which makes sure your functions actually return what
they say they do. For example, the type checker will report an error for
the following code:

```elixir
fn sum(a: Int, b: Int) : Float do
  a + b
end

# Error: "Expected type: Float, got: Int"
```

All functions in Fika are nested inside modules.
Module names in Fika are inferred from their file paths, so a Fika file named
`example.fi` will become a module named `example`. All functions inside this
file will belong to this module.

The `sum` function can be called like so:

```elixir
# Calling locally within the module
sum(40, 2)

# Calling remotely outside the module
example.sum(40, 2)
```

#### If-Else expressions
An if-else expression in Fika looks like this:
```
if true do
  a = "we have if-else now!"
  200
else
  404
end
```

#### Basic types and operators

Fika is currently a proof of concept so its data types and operators are quite
limited.

Data types - atoms, integers, strings, booleans, lists and records.
Operators - assignment(=), logical(&, |, !) and arithmetic(+, -, *, /).

```elixir
# This is a comment

# Type: Int
a = 40
b = 2
c = a + b

# Type: String
str = "Hello world"

# Type: Bool
x = true

# Type: List(Int)
list_of_ints = [1, 2, 3]

# Type: {String,Bool}
tuple = {"tuple", true}

# Type: {foo: Int}
record = {foo: 123}
```

[example.fi](https://github.com/fika-lang/fika/blob/main/example.fi) has
working examples that demonstrate the syntax.


#### Interop with Elixir and Erlang

Fika makes it easy to call functions defined externally in the BEAM:

```
# Inside module foo
ext str_length(str: String) : Int = {"Elixir.String", "length", [str]}

# Can be called using `foo.str_length("Hello world")`
```

When reaching out to functions external to Fika, the compiler
blindly trusts the type signature provided by the developer, so be careful here!


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
mix escript.build

# Call the function example.sum(1, 2) from the file example.fi
./fika exec --function="sum(1, 2)" example.fi
```

### Your first HTTP server

Fika comes with a webserver which allows you to quickly create HTTP request
handlers. By default, Fika looks for routes in a function called
`router.routes()`, so you need to define that first:

Note: This webserver is a prototype for now and only responds with strings and
a 200 status code.

```elixir
# Inside router.fi
fn routes : List({method: String, path: String, handler: Fn(->String)}) do
  [
    {method: "GET", path: "/", handler: &greet}
  ]
end

fn greet : String do
  "Hello world"
end
```

Now start the webserver in one of two ways:

#### Using Elixir shell

```
# router.fi is in the `examples` folder
> Fika.start("examples")

# Reload routes after changing routes.fi
> Fika.RouteStore.reload_routes()
```

#### Using `fika` executable

```
# Create the executable
mix escript.build

# router.fi is in the `examples` folder
./fika start examples

# Re-run the command after making changes to routes.fi
```

Now open `http://localhost:6060` in the browser to see "Hello world" served
by Fika.

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
