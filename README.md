<img src="https://github.com/fika-lang/assets/blob/master/logo.png?raw=true" width="150"/>

Fika is a modern programming language for the web.
It is statically typed, functional and runs on the BEAM (Erlang VM).
Fika is designed for building and maintaining scalable web apps without
compromising on programmer ergonomics.

Project status: Actively developed. Not ready for production.

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

#### Basic types and operators

Fika is currently a proof of concept so its data types and operators are quite
limited.

Data types - integers, strings, lists and records.
Operators - assignment and arithmetic.

```elixir
# This is a comment

# Type: Int
a = 40
b = 2
c = a + b

# Type: String
str = "Hello world"

# Type: List(Int)
list_of_ints = [1, 2, 3]

# Type: {foo: Int}
record = {foo: 123}
```

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
> Fika.Code.load_file("example.fi")

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

If you'd like to talk to us and join the Fika community, please consider joining
our [Discord server](https://discord.gg/zNs6Gs5). That's the best place to
ask questions and get guidance on contributing to Fika.
