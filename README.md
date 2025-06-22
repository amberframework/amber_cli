# Amber CLI

This tool serves as a replacement for the original AMBER framework CLI tool.

The CLI tool is no longer an integrated part of the main amber framework. This means that you do not have to install this helper tool in order to use it.

There are a few major changes between this version and the original version. 

1. I have removed some features that were not being used such as `recipes` and `plugins`.

2. There is an entirely _new_ generator command that is much more flexable than the previous generation. Please read the docs to better understand how to utilize this.




## Installation


MacOS & Linux via Homebrew: 

`brew install amber`

From source:

1. Clone the repo from the latest release tag `git clone git@
2. Install the dependencies `shards install`
3. Build the binary `crystal build src/amber_cli.cr -o amber`
4. (Optional) Build the MCP server `crystal build src/amber_mcp`


Windows:

Not directly supported at this time. This CLI tool should work as expected when using a virtual machine or WSL2.


TODO: Write usage instructions here

## Development

To get started with development:

1. **Install Crystal**: Make sure you have Crystal installed (version 1.0+ recommended)
   - macOS: `brew install crystal`
   - Ubuntu/Debian: Follow the [Crystal installation guide](https://crystal-lang.org/install/)

2. **Clone and setup**:
   ```bash
   git clone https://github.com/amberframework/amber_cli.git
   cd amber_cli
   shards install
   ```

3. **Build and test**:
   ```bash
   # Build the CLI
   crystal build src/amber_cli.cr -o amber

   # Run tests
   crystal spec

   # Run the CLI locally
   ./amber --help
   ```

4. **Development workflow**:
   - The main CLI entry point is in `src/amber_cli.cr`
   - Core functionality is organized under `src/amber_cli/core/`
   - Commands are defined in `src/amber_cli/commands/`
   - Run `crystal run src/amber_cli.cr -- <args>` to test changes without building

5. **Code style**: Follow Crystal's standard formatting with `crystal tool format`


## Contributing

1. Fork it (<https://github.com/amberframework/amber_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [crimson-knight](https://github.com/crimson-knight) - creator and maintainer
