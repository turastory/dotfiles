---
name: refine-plan
description: For a given document, write a new document that contains detailed plans for implementation, including PRs and guidelines
argument-hint: "Refine this plan document to make a detailed implementation plan."
---

Check out this document, and clarify unclear points in this doc. Ask me if you are not sure. Your final goal is to make a plan for implementation that contains:

- A reference to this document (doc for background/context)
- A stack of PRs (This work can be a large size and the range is wide - across multiple codebases, so it'd be good to split the work into parts). Each PR should have clear separation and boundry.
- A list of use cases that covers the changes for each PR.
- A list of subtasks that can be delegated to subagents.

Include this guidelines for implementation:
- Dont: uses different function/variable names for the same function (e.g. deny / reject / refuse)
- Dont: separate a simple logic as a function where it's being used in only one or two places - it can be inlined
