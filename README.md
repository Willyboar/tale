# Tale - A static story telling generator
<img width="280" align="right" alt="Tale" src="tale.png" />

[![Package Version](https://img.shields.io/hexpm/v/tale?style=for-the-badge)](https://hex.pm/packages/tale)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3?style=for-the-badge)](https://hexdocs.pm/tale/)


Tale is a static site/blog generator that ships with a CLI focused on telling stories(blogging) quickly. Designed for fast site creation and easy theme swapping and generating. Contains a basic dev server with a bare live/reload feature to help you monitor your developement. Hope you enjoy it!

There are a lot of ways to install and use **tale**.

## Installation

### Option 1

You can install tale as a dev dependency in any gleam project:

```sh 
gleam add --dev tale
```
and use it to create a new site inside your gleam project like this:

```sh
gleam run -m tale new site <name>
```

### Option 2

Clone the repository and cd into it:


```sh
git clone https://github.com/Willyboar/tale
cd tale
```

Build the escript:

```sh
gleam run -m gleescript
```


You can use the executable if you are in the same path with:

```sh
./tale
```
or add it in your PATH and use it from anywhere with:

```sh
tale
```

## Quick Start

> You can use all this commands without creating an escript by changing `tale` with `gleam run --`

### Create a new site

Once you have tale in your path you can create a new site with:

```sh
tale new site <name>
```

This command will create a new site that contains a default theme into `themes/`

You can start the developement server using:

```sh
tale serve
```

you can also set the port:

```sh
tale serve 5678
```

There is a basic watch that rebuilds the site in changes(still requires reload the browser though)

When you are ready you can build your site with:

```sh
tale build
```

and deploy the generated files into `public`

You can also configure a lot of things in `config.toml` file.

### Theme creation

You can create your own theme with:

```sh
tale new theme <name>
```

If you want to use it in your site, copy the theme into `themes/` directory on your site/blog and change the name in the `config.toml`

### Post creation

You can create a new post in any path but the recommended way is to go into `content/posts` and then type:

```sh
tale new post this_is_a_wibble_wobble_post
```


## Documentation

- Tale documentation- TODO

- Generated Internal documentation can be found at <https://hexdocs.pm/tale>.


## License

MIT
