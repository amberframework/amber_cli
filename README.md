# Amber CLI

This tool serves as a replacement for the original AMBER framework CLI tool.

The CLI tool is no longer an integrated part of the main amber framework. This means that you do not have to install this helper tool in order to use it.

There are a few major changes between this version and the original version. 

1. I have removed some features that were not being used such as `recipes` and `plugins`.

2. There is an entirely _new_ generator command that is much more flexable than the previous generation. Please read the docs to better understand how to utilize this.


## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     amber_cli:
       github: amberframework/amber_cli
   ```

2. Run `shards install`

## Usage

```crystal
require "amber_cli"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/amberframework/amber_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [crimson-knight](https://github.com/crimson-knight) - creator and maintainer
