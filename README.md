# 10xEngineer Lab hostnode toolchain

Provides basic functionality for VMs and templates.

Setup new template

	`lab-templates create NAME URL to template archive`

## Configuration Handlers

Located under handlers/*.rb, in future refactored to individual gem files, template to override specific logic.

## Use cases

* How to configure network based on lab definition

**TODO** replace external.rb with mixlib-shellout