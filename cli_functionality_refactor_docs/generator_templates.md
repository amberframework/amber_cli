# Generate Templates

The Ampere CLI's Modern Interface allows it to use customizable templates that can be updated and managed on a per project basis.

What this means is that you get the same basic starting footprint as every Amber application. But as your application grows and the patterns that you use evolve, you can add your own generators by adding a YAML or JSON configuration that our CILI tool will read from and be able to use and interpret as part of your project.

You simply add the configuration to find the areas of the names of the area of the template that you want to be able to fill in. Name the template and provide the file type and make sure you provide the conventions for where this type of file would be put depending on how the CLI tool is used. And when the CLI tool runs, it will load up your preferences, it will prefer everything that's in your current project over what its default configurations are so you can customize what the generators are that come with the Amber CLI tool and build on it from there.