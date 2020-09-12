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
fn sum(a: Int, b: Int) : Int do
  a + b
end
```

This is a function named `sum` which takes two integers and returns another integer.
Identifiers in Fika are written in snake_case (similar to Ruby, Elixir or Python).
Types are written in CamelCase.
