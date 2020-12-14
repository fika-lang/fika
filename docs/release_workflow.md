# How is Fika released?

Fika uses [Bakeware](https://github.com/spawnfest/bakeware) to create a
self-contained pre-compiled executable binary.

Fika is configured to generate said binary `fika` at the `./dist` directory upon `mix release`.

## How the release is setup

The `defp release` function in `mix.exs` defines the main parameters for the release generation.
`Fika.Deploy.copy_files/1` is a custom step that copies the self-contained binary to the `./dist` directory, relative to the current working directory.

### Caveats

The main application module is set as `Fika.Cli`, which is a `Bakeware.Script`.

We don't want the usage string to be printed and want an `IEx` shell when we run `iex -S mix` during development.
As such, the `print_usage` config for `Fika.Cli` is defined as `false` outside of Mix Releases.
