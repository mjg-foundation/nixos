---
name: codestyle
description: Apply personal code style conventions when writing, editing, or reviewing code, including naming numeric constants and deriving them from other constants.
---

# Code style

Where possible, numeric literals should be encoded as named constants, which explain their meaning, in a language-appropriate casing, typically at the top of the code file. When possible, constants that have mathematical derivations should be constructed from constant expressions using other named constants.

This rule applies to production code and test code. The only exception is numeric literals chosen as fixture values for numerical or data-processing tests.
