# AmberCLI MCP

The new CLI server comes with an MCP server built in. So when installed through Homebrew and otherwise configured, you can have an MCP server that's always running that gives you access to the standard documentation for the version of Amber that you're using in your project.

## Versions

Amber's documentation will be searchable for methods and classes that are part of the public API. By default, it'll search the latest release. There is also a list of the most recent documentation available for the last releases going back 10 releases.

## Command References

All of the commands that are available in the Amber CLI will also be documented so that your model can query about how to use them and then can actually submit to run those queries for a specific project.

If you provide the path to the route of an existing amber project, it can execute commands such as generator commands for an existing project following that project's conventions.

All applications require that you provide the name of the project or a path to the project's root folder. The only exception is initializing a new project which does not require a path. They will automatically use the user's home folder as the root and then initialize the project from there in the same way that the CLI tool would when you create a project from the terminal.
