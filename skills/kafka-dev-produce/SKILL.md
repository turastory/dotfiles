---
name: kafka-dev-produce
description: Generate CLI commands to publish test messages to Kafka topics in the dev environment.
---

# Kafka Dev Produce

Use this skill when the user wants to manually publish a message to a Kafka topic in development, test a subscriber, or send a sample event.

## What to do

- Identify the topic, message payload, and environment.
- Produce the exact CLI command needed to publish the message in dev.
- Default to a safe, explicit example payload when the user does not provide one.

## Guardrails

- Target dev only unless the user explicitly asks for something else.
- Prefer commands that are easy to rerun and edit.
- Call out placeholders clearly when values are unknown.
