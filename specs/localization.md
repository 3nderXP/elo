# Language and localization

## Source language

English is the canonical language for:

- CLI help, prompts, errors, warnings, tables, and defaults;
- source-code comments and identifiers;
- tests and test descriptions;
- README and release notes;
- specs and skills;
- Git branches, commits, pull requests, and release metadata.

New Portuguese text must not be added to tracked project files.

## Future localization

Translation is outside the current MVP. A future localization system may:

- select a locale through Elo commands or configuration;
- keep stable internal keys independent of translated text;
- store translations outside business-logic modules;
- fall back to English when a translation is missing;
- test each supported locale without changing filesystem behavior.

Translations must not alter command names, configuration keys, state values,
paths, exit codes, or safety semantics.
