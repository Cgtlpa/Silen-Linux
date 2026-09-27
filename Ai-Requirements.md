# Silen Linux Project Instructions

## Purpose

You are working on Silen Linux, a Gentoo-based Linux distribution designed around a simple, reliable, and maintainable system.

Always treat Silen Linux as its own distribution. Do not assume that instructions for Gentoo, Arch, Debian, Fedora, or other distributions apply directly.

## System Information

- Distribution: Silen Linux
- Base distribution: Gentoo
- Init system: OpenRC
- Kernel: Linux 6.12
- Architecture: Use the architecture detected from the current system unless the project specifies otherwise.
- Package manager: A custom binary package manager written in Rust
- Package format and package workflow: Use the Silen Linux package manager and repository
- Package repository: https://github.com/Cgtlpa/spk_pkgs/tree/main/packages

Most Silen Linux packages are distributed as precompiled binary packages. Packages are compiled specifically for the Silen Linux environment, so do not replace the Silen Linux package manager with Portage, emerge, apt, pacman, dnf, or another package manager unless explicitly requested.

## Package Management Rules

Before adding any installer, setup script, dependency, or package installation step:

1. Check whether the package exists in the Silen Linux package repository:
   https://github.com/Cgtlpa/spk_pkgs/tree/main/packages
2. Use the exact package name from the repository whenever possible.
3. Do not assume that a package name from another distribution is valid on Silen Linux.
4. Do not add packages from another distribution's repositories.
5. Do not compile a package manually if a Silen Linux binary package is available.
6. Do not modify the package manager, package format, package repository, or package-building system unless it is strictly necessary.
7. If a required package is missing from the repository, stop and report it clearly.

When a package is missing, use this format:

```text
Missing package:
- Requested software: <software name>
- Suggested package name: <package name>
- Why it is needed: <short explanation>

This package is not currently present in the Silen Linux package repository. Please add it before continuing.
```

Do not silently substitute a different package or installation method.

## Protecting Existing Infrastructure

The Silen Linux package manager and package infrastructure are important system components.

Do not:

- Replace the package manager.
- Rewrite package-management code without a strong reason.
- Change package formats unnecessarily.
- Replace binary packages with source builds without approval.
- Assume standard Gentoo behavior is correct for Silen Linux.
- Change system-wide configuration without checking the existing project structure.
- Remove working code merely because a different design appears cleaner.

Before changing package-management-related code:

1. Inspect the existing implementation.
2. Identify how it is currently used.
3. Check whether the proposed change affects compatibility.
4. Explain the risk.
5. Ask for approval before making a potentially disruptive change.

## Installation and Installer Requirements

When creating or modifying an installer:

- Check every package against the Silen Linux package repository first.
- Use the Silen Linux package manager for installation.
- Respect OpenRC instead of assuming systemd.
- Use Linux kernel 6.12 assumptions only when they are relevant to the task.
- Avoid hardcoding paths, package names, services, or commands from other distributions.
- Detect the system before making changes where practical.
- Make installer failures clear and actionable.
- Prefer safe, repeatable, and idempotent installation steps.
- Do not overwrite user configuration without permission.
- Do not delete existing files or packages without explaining the impact.

Before installing a service, verify:

- The package exists.
- The service has an OpenRC service script.
- The service can be enabled and started using the Silen Linux/OpenRC workflow.
- Any required users, groups, directories, permissions, and configuration files are handled correctly.

## Code Style

Code must be:

- Clean.
- Simple.
- Readable.
- Easy to maintain.
- Easy to debug.
- Written with clear and descriptive function names.
- Organized into small functions with one clear responsibility.
- Consistent with the existing project style.
- Compatible with the project's existing language version and build system.

Prefer straightforward code over clever abstractions.

Avoid:

- Unnecessary frameworks.
- Deeply nested logic.
- Unclear abbreviations.
- Large functions that perform unrelated tasks.
- Premature optimization.
- Unnecessary dependencies.
- Unrequested refactors.
- Rewriting working sections without a clear benefit.

Do not add comments to normal code unless they are specifically requested or are necessary to explain something that cannot be made clear through code structure.

## Debugging and Code Sections

When debugging or changing code, organize the work into named sections.

Use section names that describe the purpose of the change, such as:

```text
Section: Package Repository Validation
Section: Installer Dependency Checks
Section: OpenRC Service Setup
Section: Configuration Generation
Section: Error Handling
```

Use the same section names consistently across future changes.

Before modifying an existing section:

1. Search for the section name.
2. Read the current implementation.
3. Determine whether the problem has already been addressed.
4. Reuse or improve the existing solution instead of creating a duplicate.
5. Preserve previous fixes unless there is a specific reason to replace them.

When presenting a patch or implementation, identify which sections were changed.

Example:

```text
Changed sections:
- Package Repository Validation
- Installer Dependency Checks

Unchanged sections:
- OpenRC Service Setup
- Configuration Generation
```

Do not create multiple implementations of the same behavior in different parts of the project.

## Planning Before Changes

Before writing code for a non-trivial task:

1. Inspect the repository structure.
2. Find the relevant existing files.
3. Check the build system and project conventions.
4. Check the package repository for required software.
5. Identify possible compatibility problems.
6. Explain the planned changes briefly.
7. Ask for approval if the change could break existing behavior, modify system infrastructure, or require a missing package.

For small, low-risk fixes, you may proceed directly after inspecting the relevant code.

## Risk and Approval Rules

If you think something might not work, say so before implementing it.

Use this format:

```text
Potential issue:
- What may fail: <description>
- Why it may fail: <reason>
- Affected systems or files: <scope>
- Proposed solution: <solution>
- Risk level: low | medium | high

Should I implement this change?
```

Wait for approval before making medium- or high-risk changes.

Approval is required before:

- Changing the package manager.
- Changing package-management behavior.
- Replacing existing installation logic.
- Removing or renaming public interfaces.
- Changing system-wide defaults.
- Deleting files or configuration.
- Adding a package that is not in the Silen Linux repository.
- Using a workaround that may reduce system reliability.
- Making a change that could break existing installations.

## Testing

After making a change:

1. Build or syntax-check the affected code.
2. Run the project's existing tests.
3. Test the changed behavior directly when possible.
4. Check error handling.
5. Check that the change works with OpenRC rather than systemd.
6. Verify that all required packages are available in the Silen Linux package repository.
7. Report exactly what was tested and what could not be tested.

Do not claim that something works if it was not tested.

Use this reporting format:

```text
Validation:
- Build or syntax check: passed | failed | not run
- Tests: passed | failed | not available
- Installer test: passed | failed | not run
- Package repository check: passed | failed
- OpenRC compatibility check: passed | failed | not applicable

Notes:
- <important limitations or remaining concerns>
```

## Error Handling

Errors should:

- Explain what failed.
- Include the relevant package, file, command, or subsystem.
- Suggest a practical next step.
- Avoid hiding failures.
- Avoid silently continuing after a required step fails.

Prefer actionable errors such as:

```text
The package `example-package` is required but was not found in the Silen Linux package repository. Add the package to the repository before running this installer.
```

Avoid vague errors such as:

```text
Something went wrong.
```

## Repository and Dependency Checks

Whenever external software is needed:

- Check the Silen Linux package repository first.
- Confirm the exact package name.
- Check whether the software is already available in the project.
- Avoid adding duplicate dependencies.
- Report missing packages before changing the installer or source code.

The repository to check is:

https://github.com/Cgtlpa/spk_pkgs/tree/main/packages

If the repository cannot be accessed, do not guess. Report that the package check could not be completed and ask whether to continue.

## Documentation

Documentation should be concise and practical.

When documenting a feature or change, include:

- What it does.
- Which files were changed.
- Which packages are required.
- How to build or run it.
- How to test it.
- Known limitations.
- Any OpenRC-specific setup.
- Any required user approval or manual steps.

Use copy-ready commands when commands are needed.

Do not document commands that have not been verified unless they are clearly marked as untested.

## Communication Style

Be direct and practical.

For each task:

1. State what you found.
2. State what you plan to change.
3. Mention package availability.
4. Mention risks or compatibility concerns.
5. Ask for approval when required.
6. Implement only the approved scope.
7. Report the result and validation status.

Do not make unrelated improvements while working on a focused task.

If the requested approach conflicts with Silen Linux's architecture, explain the conflict and suggest a compatible alternative.

## Priority Order

When making decisions, follow this priority order:

1. Preserve system stability.
2. Preserve compatibility with Silen Linux.
3. Use the Silen Linux package manager and package repository.
4. Respect the existing project structure and previous fixes.
5. Keep the implementation simple and readable.
6. Avoid unnecessary changes.
7. Optimize only after correctness and maintainability are established.

## System Philosophy

Silen Linux should be a stable, predictable, and unobtrusive operating system.

When making changes or adding features:

- Prioritize reliability and stability over unnecessary features.
- Prefer predictable behavior over clever or surprising behavior.
- Keep the system quiet and avoid unnecessary notifications, prompts, background services, telemetry, or interruptions.
- Do not interfere with the user's workflow unless user input is genuinely required.
- Avoid changing user preferences or configuration without permission.
- Do not add startup programs, daemons, timers, services, or scheduled tasks unless they are necessary.
- Avoid consuming unnecessary CPU, memory, disk space, or network bandwidth.
- Keep defaults sensible and minimal.
- Make features available when needed without forcing them into the user's workflow.
- Do not repeatedly ask the user to configure or approve routine operations.
- Fail safely and provide a clear error when an operation cannot continue.
- Prefer reversible changes and preserve existing configuration.
- Do not sacrifice system stability for convenience or visual polish.
- Avoid unnecessary updates, migrations, rewrites, and background maintenance.
- Keep the system out of the user's way while remaining transparent when something important happens.

A good Silen Linux feature should feel invisible during normal use: it should work reliably when needed, avoid unnecessary interference, and remain understandable and controllable when the user wants to inspect or change it.
