# Amber CLI Functionality Audit & Planning Document

> **Purpose**: This document maps out all current functionality in the Amber CLI to determine what should be kept, modified, or removed for the new version supporting Amber 1.4+

## Overview

The Amber CLI provides comprehensive tooling for Crystal-based web application development using the Amber framework. The CLI is organized into four main functional areas:

1. **Commands** - Direct CLI operations for project management
2. **Generators** - Code generation utilities for scaffolding
3. **Helpers** - Utility functions for common operations  
4. **Templates** - Template files for code generation

---

## 1. Commands (`src/amber_cli/commands/`)

### Core Application Commands

#### `new` (`new.cr`)
**Purpose**: Create new Amber applications
- **Options**:
  - `name` - Project name/path (required)
  - `-d` - Database engine: `pg | mysql | sqlite` (default: pg)
  - `-t` - Template engine: `slang | ecr` (default: slang)
  - `-r` - Named recipe for customization
  - `--no-color` - Disable colored output
  - `-y, --assume-yes` - Skip interactive prompts
  - `--no-deps` - Skip dependency installation
- **Functionality**:
  - Creates project directory structure
  - Validates project names (no spaces, Crystal keywords)
  - Supports recipes for customization
  - Auto-encrypts production.yml
  - Runs `shards update` unless `--no-deps`

#### `generate` (`generate.cr`)
**Purpose**: Generate application components from templates
- **Types**: `scaffold, api, model, controller, migration, mailer, socket, channel, auth, error`
- **Options**:
  - `type` - Generator type (required)
  - `name` - Resource name
  - `fields` - Field definitions (e.g., `name:string`, `age:integer`)
  - `--no-color` - Disable colored output
  - `-y, --assume-yes` - Skip interactive prompts
- **Functionality**:
  - Supports both built-in generators and recipe-based generation
  - Validates input parameters
  - Interactive mode for confirmations

### Development Tools

#### `watch` (`watch.cr`)
**Purpose**: Development server with file watching and auto-rebuild
- **Functionality**:
  - Inherits from `Sentry::SentryCommand`
  - Watches for file changes
  - Auto-rebuilds and restarts server
  - Color output support

#### `exec` (`exec.cr`)
**Purpose**: Execute Crystal code within application scope
- **Options**:
  - `code` - Crystal code or .cr file to execute
  - `-e, --editor` - Preferred editor (default: vim)
  - `-b, --back` - Run previous command files
  - `--no-color` - Disable colored output
- **Functionality**:
  - Interactive REPL-like experience
  - Supports running code files
  - History management for previous executions
  - Automatic application context loading

### Database Management

#### `database` (`database.cr`)
**Purpose**: Database operations and migrations (powered by micrate)
- **Commands**:
  - `drop` - Drop database
  - `create` - Create database
  - `migrate` - Run migrations
  - `rollback` - Roll back one migration
  - `redo` - Re-run latest migration
  - `status` - Show migration status
  - `version` - Show current database version
  - `seed` - Run seed data
- **Functionality**:
  - Supports PostgreSQL, MySQL, SQLite
  - Environment-based configuration
  - Connection testing and management

### Application Analysis

#### `routes` (`routes.cr`)
**Purpose**: Display and analyze application routes
- **Options**:
  - `--no-color` - Disable colored output
  - `--json` - Output as JSON format
- **Functionality**:
  - Parses `config/routes.cr`
  - Supports resource routes, custom routes, websockets
  - Pipeline and scope detection
  - Tabular and JSON output formats
  - Action mapping for RESTful resources

#### `pipelines` (`pipelines.cr`)
**Purpose**: Display application pipeline configuration
- **Options**:
  - `--no-color` - Disable colored output
  - `--no-plugs` - Hide plug information
- **Functionality**:
  - Parses pipeline definitions
  - Shows pipe and plug relationships
  - Tabular output with customizable columns

### Security & Configuration

#### `encrypt` (`encrypt.cr`)
**Purpose**: Encrypt/decrypt environment configuration files
- **Options**:
  - `env` - Environment to encrypt (default: production)
  - `-e, --editor` - Preferred editor
  - `--noedit` - Skip editing, just encrypt
- **Functionality**:
  - Encrypts YAML environment files
  - Interactive editing workflow
  - Automatic cleanup of unencrypted files

#### `plugin` (`plugin.cr`)
**Purpose**: Plugin management (currently install-only)
- **Options**:
  - `name` - Plugin name (required)
  - `-u, --uninstall` - Uninstall plugin (not implemented)
  - `args` - Template rendering arguments
- **Functionality**:
  - Plugin installation from templates
  - Template-based plugin generation
  - **Note**: Uninstall functionality not currently supported

---

## 2. Generators (`src/amber_cli/generators/`)

### Web Application Generators

#### `app.cr`
**Purpose**: Full application scaffolding
- **Features**: Complete project structure, configuration files, basic layout

#### `scaffold.cr` 
**Purpose**: Full CRUD scaffolding for resources
- **Components**: Model, controller, views, routes, migrations

#### `api.cr`
**Purpose**: API-only application structure
- **Features**: JSON-focused, minimal view layer

### MVC Components

#### `model.cr`
**Purpose**: Generate data models
- **Features**: ORM integration, field definitions, validations

#### `controller.cr`
**Purpose**: Generate controllers
- **Features**: Action methods, routing integration

#### `scaffold_controller.cr`
**Purpose**: Generate controllers with full CRUD operations
- **Features**: RESTful actions, parameter handling

#### `scaffold_view.cr` 
**Purpose**: Generate view templates for scaffolded resources
- **Features**: Form helpers, listing views, detail views

### Real-time & Communication

#### `channel.cr`
**Purpose**: Generate WebSocket channels
- **Features**: Real-time communication setup

#### `socket.cr`
**Purpose**: Generate WebSocket socket handlers
- **Features**: Connection management, message handling

#### `mailer.cr`
**Purpose**: Generate email mailers
- **Features**: Template-based email generation

### Authentication & Security

#### `auth.cr` 
**Purpose**: Generate authentication system
- **Features**: User model, session management, login/logout

#### `error.cr`
**Purpose**: Generate error handling controllers
- **Features**: Custom error pages, exception handling

### Data Management

#### `migration.cr`
**Purpose**: Generate database migrations
- **Features**: Schema changes, data transformations

#### `empty_migration.cr`
**Purpose**: Generate empty migration templates
- **Features**: Blank migration structure

#### `field.cr`
**Purpose**: Field definition and validation utilities
- **Features**: Type validation, field parsing

### Core Generator Infrastructure

#### `generator.cr`
**Purpose**: Base generator functionality and registration system
- **Features**: 
  - Command registration
  - Template rendering
  - File generation utilities
  - Crystal keyword validation

---

## 3. Helpers (`src/amber_cli/helpers/`)

### Process Management

#### `process_runner.cr`
**Purpose**: External process execution utilities
- **Features**: Shell command execution, output handling, error management

#### `sentry.cr`
**Purpose**: File watching and development server management
- **Features**: File system monitoring, automatic rebuilding, server lifecycle

### Migration Utilities

#### `migration.cr`
**Purpose**: Database migration helper functions
- **Features**: Migration file management, timestamp generation

### General Utilities

#### `helpers.cr`
**Purpose**: Common utility functions
- **Features**:
  - Route injection (`add_routes`)
  - Pipeline/plug management (`add_plugs`)
  - Dependency injection (`add_dependencies`)
  - Command execution (`run`)

---

## 4. Templates (`src/amber_cli/templates/`)

### Application Templates

#### `app/`
**Purpose**: Full application template structure
- **Components**:
  - Configuration files (`config/`)
  - Database setup (`db/`)
  - Docker configuration
  - Public assets (`public/`)
  - Source code structure (`src/`)
  - Spec setup (`spec/`)
  - Project files (`shard.yml`, `README.md`, `.gitignore`)

### Component Templates

#### `controller/`
**Purpose**: Controller generation templates
- **Features**: Action methods, route integration

#### `model/`
**Purpose**: Model generation templates  
- **Features**: ORM setup, field definitions

#### `migration/`
**Purpose**: Migration file templates
- **Variants**: 
  - `empty/` - Blank migrations
  - `full/` - Table creation migrations

#### `scaffold/`
**Purpose**: Full CRUD scaffolding templates
- **Components**:
  - `controller/` - CRUD controller
  - `view/` - Complete view set (index, show, new, edit, form partials)

### Specialized Templates

#### `auth/`
**Purpose**: Authentication system templates
- **Components**: User model, session controller, views, migrations

#### `error/`
**Purpose**: Error handling templates
- **Components**: Error controller, error pages, pipe setup

#### `api/`
**Purpose**: API-specific controller templates
- **Features**: JSON responses, API-focused structure

#### `mailer/`
**Purpose**: Email template generation
- **Components**: Mailer classes, HTML/text templates

#### `channel/` & `socket/`
**Purpose**: WebSocket communication templates
- **Features**: Real-time connection handling

---

## 5. Supporting Infrastructure

### Recipe System (`src/amber_cli/recipes/`)

#### `recipe.cr` & `recipe_fetcher.cr`
**Purpose**: Custom project template system
- **Features**:
  - Remote recipe fetching
  - Custom project scaffolding
  - Template customization

### Plugin System (`src/amber_cli/plugins/`)

#### `plugin.cr` & `installer.cr`
**Purpose**: Plugin management infrastructure
- **Features**:
  - Plugin discovery
  - Template-based installation
  - Configuration management

### Configuration (`src/amber_cli/config.cr`)
**Purpose**: CLI configuration management
- **Features**: Project settings, database configuration, template preferences

---

## Analysis & Recommendations

### Strengths
1. **Comprehensive Coverage**: Full-stack development support
2. **Template System**: Flexible code generation
3. **Database Support**: Multi-database compatibility
4. **Development Tools**: Live reloading, REPL, route analysis
5. **Security Features**: Built-in encryption for sensitive configs

### Areas for Review

#### High Priority (Likely Keep)
- Core commands: `new`, `generate`, `database`, `watch`
- Essential generators: `model`, `controller`, `migration`, `scaffold`
- Development helpers: file watching, process management
- Application templates: full app structure

#### Medium Priority (Evaluate)
- Plugin system (currently limited, uninstall not working)
- Recipe system (assess usage and maintenance burden)  
- Specialized generators: `auth`, `error` (evaluate framework changes)
- Pipeline analysis tools (assess if still relevant)

#### Low Priority (Consider Removal)
- `exec` command (REPL functionality)
- WebSocket generators (`channel`, `socket`) if framework doesn't support
- API-specific templates if regular templates suffice
- Legacy template engines if framework standardizes

### Framework Compatibility Concerns
1. **Template Engines**: Verify `slang` and `ecr` support in Amber 1.4+
2. **Database Integration**: Confirm `micrate` compatibility
3. **WebSocket Support**: Validate real-time features in new framework
4. **Authentication**: Check if auth patterns have changed
5. **Pipeline System**: Verify middleware/pipeline concepts

### Next Steps
1. Test each component against Amber 1.4+ requirements
2. Identify deprecated or changed framework APIs
3. Prioritize components based on user feedback and usage analytics
4. Plan migration strategy for breaking changes
5. Consider consolidating similar functionality 