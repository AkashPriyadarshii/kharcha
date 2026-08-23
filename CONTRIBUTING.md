# Contributing to Kharcha

Kharcha is a private repository currently developed by Akash. However, if you are a collaborator or an AI agent working on this repo, you MUST strictly adhere to these guidelines.

## The Ponytail Method
All code in this project follows the "ponytail method."
Read docs/ponytail.md for full details, but the core principles are:
1. **YAGNI (You Aren't Gonna Need It):** No speculative features or abstractions.
2. **Smallest Change:** Only touch the exact lines necessary for the ticket.
3. **Delete Over Add:** If a feature is removed, delete the dead code immediately.
4. **Boring Over Clever:** Code must be readable and explicit. Avoid excessive magic.
5. **No External Dependencies:** If it can be done with the standard library or an existing package, do not add a new dependency.

## Strict Limits
- **NO AI/LLM:** Do not integrate any AI SDKs, APIs, or features. Automation is rule-based.
- **NO Third-party Telemetry:** We use our own Supabase app_errors table for logs. No Firebase, no Sentry.
- **NO Ad libraries.**

## Development Workflow
1. Branch off main (feat/ or fix/).
2. Write tests covering your change (mandatory).
3. Ensure 'flutter analyze' and 'flutter test' both pass cleanly.
4. Submit a PR. The PR description must explicitly state what was changed and how it was tested.
5. **Documentation:** Update docs/state.md, docs/changelog.md, and any other relevant Markdown files in the *same commit* as your code change.

Thank you for building a better expense tracker!