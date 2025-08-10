<h1 align="center">🌶️ <span style="font-family: monospace">sriracha</span> 🌶️</h1>

<p align="center">
  <i align="center">Type-safe ⚡️ hot <s>sauce</s> source reloading ⚡️ for OCaml 🐪</i>
</p>

## Introduction

Sriracha is a library for type-safe hot-reloading of OCaml functions, inspired by
[subsecond](https://github.com/DioxusLabs/dioxus/tree/main/packages/subsecond).

## Usage

🌶️ `sriracha` 🌶️ consist of two parts: the loader, and the application.

The loader is responsible for locating and starting the application[^start], and determining when
to reload.

[^start]: The sriracha library is deliberately agnostic to how you build your app, and has minimal
    dependencies. It just provides the bare minimum reloading abstraction -- you can bring the file
    watcher and/or concurrency framework.

The application provides a loader-specific entry point, and contains hot-reloadable
functions.

Both the loader and application should depend on the core Sriracha library. Your application
should (perhaps surprisingly) depend on your loader[^loader], `ppx_sriracha`, and `ppx_typerep_conv`.

[^loader]: This allows your loader to specify what type of main function it expects (`unit -> unit`,
`unit -> unit Deferred.t`, etc.).

A basic example of a loader is provided in `loader/`, but for more complicated use-cases,
you likely want to build your own loader.

See [hot_loader.ml](loader/hot_loader.ml) for a basic hot-loader built on top of async.

See [example.ml](example/example.ml) for an example application.

<h3>Running the example application</h3>

```bash
# run this in one terminal
$ dune build example/example.cmxs loader/bin/loader.exe --auto-promote --watch

# in another terminal
$ _build/default/loader/bin/loader.exe _build/default/example/example.cmxs
```

You can then make edits to `example.ml` (e.g. changing the text printed by `do_something`).
Notice how only changes in, or "downstream" of `do_something` affect the runtime behaviour.

## How it works

Sriracha makes use of the OCaml [`Dynlink`](https://ocaml.org/manual/5.3/api/Dynlink.html#top)
library. It builds a type-safe jump table from function name to function pointer, and redirects
calls to hot-reloadable functions via the jump table. This jump table is updated as the program
live reloads.

There are two parts to an application using Sriracha: the loader, and the application.

The loader is a very simple (approximately application agnostic) executable, which bundles
all of the application's dependencies (see notes below -- this is quite annoying), and is
responsible for (re-)loading the application, and launching it.

The application is just the application you want to live reload. For the most part, all you
need to do is to define an entry point for the loader to call, and to annotate reloadable
functions as `let%hot`.

It's likely that a more complete integration with this library will require e.g. your web
framework to be aware of hot reloading. In the future, we'll likely provide hooks to
receive updates about e.g. hot reloads happening to clean-up after old versions of your
code as necessary.

<!-- for some reason this doesn't render properly as ## without this comment here -->
## Ideas

- [ ] add a flag to `ppx_sriracha` to statically remove all of the hot-reloading points in
  release builds.
- [ ] handle nested function calls correctly (e.g. detect a new function being called
  within an old function.
- [ ] add some better notes about caveats/limitations of the library, e.g. the interaction
  with global state, etc.
- [ ] build a more complete example, e.g. a web server with Dream.
- [ ] thread safety?

<!-- for some reason this doesn't render properly as ## -->
<h2>Misc notes</h2>

Reasons this was hard to get right:

- Dependencies have to be linked into the loader, and it's quite easy for those dependencies
  to accidentally be dead-code eliminated.
- User applications can't have both dynamic and static versions of a single application
  (which would also solve the dependency problem), since you end up with module name clashes.
  _Maybe we can do some name mangling?_

