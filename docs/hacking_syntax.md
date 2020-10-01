Fika Syntax Hacking Guide
=========================

Changing Fika's syntax is a 3 step process:

1. Update the parser to understand the new syntax
2. Update the type checker so it can infer types of AST nodes parsed from the new syntax
3. Update Erl translator convert the new Fika AST nodes to Erlang abstract format.

These are explained below.

#### 1. Parser

It's the parser's job to read strings containing Fika code, parse them into
an Abstract Syntax Tree or return an error if the code is invalid.
Fika uses [NimbleParsec](https://github.com/dashbitco/nimble_parsec), a
parser library written in Elixir to do this. The code for this can be
found [here](https://github.com/fika-lang/fika/blob/8e2e92df6b6cdb5c73f1921e9a1b7a3545c2421f/lib/fika/parser.ex)

If you write a parser that hangs, you most probably have the "left recursion"
problem. [Read this](https://web.cs.wpi.edu/~kal/PLT/PLT4.1.2.html)
to understand how to fix this problem. An example of this is how we're parsing
`exp_bin_op`. Head over to the Discord server if you need more help.

#### 2. TypeChecker

The TypeChecker's job is to make sure the function definitions have return
types in their signature that actually match the types inferred from their body.

The code can be found [here](https://github.com/fika-lang/fika/blob/8e2e92df6b6cdb5c73f1921e9a1b7a3545c2421f/lib/fika/type_checker.ex)

Expressions are inferred using a function called `infer_exp(env, exp)`.
The first argument `env` is the state that's maintained by the type checker.
When new types are inferred, they're added to the env so it can be looked up
later when needed. The second argument `exp` is the AST node for the expression
as parsed by the Parser module. This function should either return `{:ok, <type>, env}`
if a type was inferred or `{:error, <message string>}` otherwise. `<type>` can
be anything which can be converted to a string. For example,
it can be an `"Int"` or it can be a structure like `%FunctionRef{}` which has
implemented a `to_string`.


#### 3. ErlTranslate

This module is in charge of converting Fika's AST into Erlang Abstract Format.
Erlang Abstract Format (sometimes called absform or simply forms in code) is
a [well documented specification](https://erlang.org/doc/apps/erts/absform.html)
for the Erlang parse tree.

To understand how a piece of code should be represented in absform, a neat little
trick I use is to write it first in Elixir and then ask the Elixir compiler
to give me the erlang representation:

```
code = """
x + 1 > 2
"""

code
|> Code.string_to_quoted!()
|> :elixir.quoted_to_erl(:elixir.env_for_eval([]))
```

ErlTranslate uses a function `translate_exp(node)` to translate an expression
into Erlang abstract format.
