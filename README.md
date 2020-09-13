<img src="https://github.com/fika-lang/assets/blob/master/logo.png?raw=true" width="150"/>

Fika is a modern programming language for the web.
It is statically typed, functional and runs on the BEAM (Erlang VM).
Fika is designed for building and maintaining scalable web apps without
compromising on programmer ergonomics.

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

Fika has a type checker which makes sure your function actually return what
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

Data types - integers, strings and lists.
Operators - assignment and arithmetic.

```elixir
# Type: Int
a = 40
b = 2
c = a + b

# Type: String
str = "Hello world"

# Type: List(Int)
list_of_ints = [1, 2, 3]
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
