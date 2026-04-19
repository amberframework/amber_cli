# Amber CLI

[![Crystal CI](https://github.com/amberframework/amber_cli/actions/workflows/crystal.yml/badge.svg)](https://github.com/amberframework/amber_cli/actions/workflows/crystal.yml)
[![GitHub release](https://img.shields.io/github/release/amberframework/amber_cli.svg)](https://github.com/amberframework/amber_cli/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://amberframework.github.io/amber_cli/)

A powerful command-line tool for managing Crystal web applications built with the [Amber Framework](https://amberframework.org). This CLI provides generators, database management, development utilities, and more to streamline your Amber development workflow.

## 📖 Documentation

**[→ Complete Documentation](https://amberframework.github.io/amber_cli/)**

The comprehensive documentation includes detailed guides, examples, and API references generated from the codebase.

## 🚀 Quick Start

### Installation

**macOS & Linux via Homebrew:**
```bash
brew tap amberframework/amber_cli
brew install amber_cli
```

**From Source:**
```bash
git clone https://github.com/amberframework/amber_cli.git
cd amber_cli
shards install
crystal build src/amber_cli.cr -o amber --release
crystal build src/amber_lsp.cr -o amber-lsp --release
sudo mv amber amber-lsp /usr/local/bin/
```

**Windows:**
Use WSL2 or a virtual machine. Native Windows support is not currently available.

### Package Manager Compatibility

Amber CLI is designed to work with upstream `crystal-lang/shards`, and we also
validate it against the additive fork currently distributed as `shards-alpha`.
The goal is straightforward: standard Amber workflows should continue to work
with plain `shards` commands, while compatible forks can add tooling without
changing how a new Amber project gets started.

### Create Your First App

```bash
# Create a new Amber application
amber new my_blog

# Navigate to your app
cd my_blog

# Set up the database
amber database create
amber database migrate

# Start the development server
amber watch
```

Your application will be available at `http://localhost:3000`

## ⚡ Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `new` | Create a new Amber application | `amber new my_app -d pg -t slang` |
| `generate` | Generate application components | `amber generate model User name:String` |
| `database` | Database operations and migrations | `amber database migrate` |
| `watch` | Development server with auto-reload | `amber watch` |
| `routes` | Display application routes | `amber routes --json` |
| `exec` | Execute Crystal code in app context | `amber exec 'puts User.count'` |
| `encrypt` | Manage encrypted environment files | `amber encrypt production` |
| `pipelines` | Show pipeline configuration | `amber pipelines` |
| `setup:lsp` | Configure the Amber LSP for Claude Code | `amber setup:lsp` |

Run `amber --help` or `amber [command] --help` for detailed usage information.

## 🔧 Key Features

### **Flexible Code Generation**
- Built-in generators for models, controllers, views, and more
- Configurable custom generators with YAML/JSON configuration
- Intelligent word transformations (snake_case, PascalCase, pluralization)
- Template-based file generation with variable substitution

### **Database Management**
- Full migration support with rollback capabilities
- Multi-database support (PostgreSQL, MySQL, SQLite)
- Database seeding and status reporting
- Environment-specific configuration

### **Development Tools**
- File watching with automatic rebuild and restart
- Interactive code execution within application context
- Route analysis and pipeline inspection
- Environment file encryption for security

### **Amber LSP — AI-Assisted Development**
- Built-in Language Server Protocol (LSP) server for Claude Code integration
- 15 convention rules that catch framework mistakes as you type
- Custom YAML-based rules for project-specific conventions
- One command to set up: `amber setup:lsp`

### **Extensible Architecture**
- Plugin system for extending functionality
- Command registration system for custom commands
- Template engine for flexible file generation
- Configuration-driven behavior

## 🏗️ Architecture Highlights

### **Zero External Dependencies**
- Built entirely with Crystal's standard library
- No external CLI frameworks or template engines
- Fast compilation and lightweight binary

### **Clean Command Structure**
- Base command class for consistent behavior
- Command registry for easy extension
- Built-in option parsing and validation
- Comprehensive error handling

### **Smart Template System**
- ECR-based template processing
- Variable substitution with transformations
- Conditional file generation
- Post-generation command execution

## 🤖 Amber LSP — The Default Development Workflow

Amber ships with a diagnostics-only Language Server that integrates with [Claude Code](https://claude.ai/claude-code). When you develop with Claude Code, the LSP runs in the background and automatically catches framework convention violations — wrong controller names, missing methods, bad inheritance, file naming issues, and more. Claude sees these diagnostics and self-corrects without you having to notice or intervene.

**This is the recommended way to develop with Amber.** The LSP turns Claude Code from a general-purpose coding assistant into one that understands Amber's conventions natively.

### Quick Setup

```bash
# From your Amber project directory:
amber setup:lsp
```

This creates three files:

| File | Purpose |
|------|---------|
| `.lsp.json` | Tells Claude Code where the LSP binary is and what files it handles |
| `.claude-plugin/plugin.json` | Plugin manifest so Claude Code discovers the LSP |
| `.amber-lsp.yml` | Rule configuration — customize severity, disable rules, add custom rules |

Then open Claude Code in your project. The LSP activates automatically.

### What It Checks

The LSP ships with 15 built-in rules covering controllers, jobs, channels, pipes, mailers, schemas, routing, file naming, directory structure, and more. Every rule maps to an Amber convention — if Claude generates a controller that doesn't end with `Controller`, or a job without a `perform` method, the LSP flags it immediately.

### Custom Rules

You can define project-specific rules in `.amber-lsp.yml` using regex patterns. No recompilation needed:

```yaml
custom_rules:
  - id: "project/no-puts"
    description: "Do not use puts in production code"
    severity: warning
    applies_to: ["src/**"]
    pattern: "^\\s*puts\\b"
    message: "Avoid 'puts' in production code. Use Log.info instead."
```

### Building the LSP Binary

If `amber-lsp` is not on your PATH, the `setup:lsp` command will offer to build it:

```bash
cd ~/open_source_coding_projects/amber_cli
crystal build src/amber_lsp.cr -o bin/amber-lsp --release
```

For full documentation on all 15 rules, configuration options, and custom rule syntax, see the [LSP Setup Guide](https://github.com/crimson-knight/amber/blob/master/docs/guides/lsp-setup.md).

## 📚 Examples

### Generate a Blog Post Resource
```bash
# Create model, controller, views, and migration
amber generate scaffold Post title:String content:Text published:Bool

# Or generate individually
amber generate model Post title:String content:Text
amber generate controller Posts
amber generate migration add_published_to_posts published:Bool
```

### Custom Development Workflow
```bash
# Watch with custom build commands
amber watch --build "crystal build src/app.cr --release" --run "./app"

# Execute code in application context
amber exec 'Post.where(published: true).count'

# Encrypt production environment
amber encrypt production --editor vim
```

### Database Operations
```bash
# Create and set up database
amber database create
amber database migrate
amber database seed

# Check migration status
amber database status

# Rollback last migration
amber database rollback
```

## 🔍 Configuration

Amber CLI uses several configuration files:

- **`.amber.yml`** - Project-specific settings
- **`config/environments/`** - Environment configurations  
- **`generator_configs/`** - Custom generator definitions

Example `.amber.yml`:
```yaml
database: pg
language: slang
model: granite
watch:
  run:
    build_commands:
      - "crystal build ./src/my_app.cr -o bin/my_app"
    run_commands:
      - "bin/my_app"
    include:
      - "./config/**/*.cr"
      - "./src/**/*.cr"
```

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`crystal spec`)
5. Follow Crystal's code formatting (`crystal tool format`)
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a Pull Request

## 📋 Requirements

- **Crystal** 1.0+ (latest stable recommended)
- **Git** (for project templates)
- **Database** (PostgreSQL, MySQL, or SQLite)

## 🐛 Troubleshooting

Common issues and solutions:

**Database connection errors:**
```bash
# Verify database is running and check config
amber database status
```

**Generation failures:**
```bash
# Check template availability
amber generate --list
```

**Watch mode not working:**
```bash
# Show current configuration
amber watch --info
```

For more detailed troubleshooting, see the [full documentation](https://amberframework.github.io/amber_cli/).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Acknowledgments

- [Amber Framework](https://amberframework.org) - The Crystal web framework
- [Crystal Language](https://crystal-lang.org) - The programming language
- All the amazing [contributors](https://github.com/amberframework/amber_cli/contributors)

---

**[→ View Complete Documentation](https://amberframework.github.io/amber_cli/)**
