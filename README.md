# amber_cli

This is a WIP tool that takes the Amber CLI out of the same repo as the Amber framework itself.

This allows us to build a CLI tool that isn't tightly coupled to release versions of Amber.

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
