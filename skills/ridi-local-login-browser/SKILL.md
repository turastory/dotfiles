---
name: ridi-local-login-browser
description: Makes the current Cursor browser tab logged in for RIDI local preflight by creating the localstamp user, issuing a ridi-at token, setting the .local.ridi.io cookie, and verifying accounts/me. Use when the user asks to make a browser tab logged in, set local login state, or prepare RIDI preflight as logged-in.
---

# RIDI Local Browser Login

Use this skill to make a Cursor browser tab logged in on RIDI local domains. Focus only on login state; ignore feature-specific expected UI unless the user asks for it.

## Preconditions

- Local `backends` and the local account route are running.
- The target browser tab is on `https://*.local.ridi.io`, or can be navigated to a local preflight URL.
- Browser MCP tool descriptors have been read before calling `CallMcpTool`.

## Workflow

1. Inspect browser tabs with `browser_tabs` action `list`.
2. If a target tab exists, lock it with `browser_lock`. If not, navigate a tab to the user-provided local URL or default to `https://preflight.local.ridi.io/event/900001`, then lock it.
3. Generate a fresh local login token from the repo root:

```bash
cd backends
DOT_ENV=.env.dev TS_NODE_PROJECT=tsconfig.json pnpm exec ts-node --transpile-only -r tsconfig-paths/register ../.cursor/skills/ridi-local-login-browser/scripts/create-local-login-token.ts
```

4. Extract `at` from the JSON output. Do not include the full token in the final user response.
5. Verify the token before touching the browser:

```bash
TOKEN='<at>'
curl -sk -o /tmp/ridi-account-me.json -w '%{http_code}\n' \
  'https://account.local.ridi.io/accounts/me' \
  -H 'Origin: https://preflight.local.ridi.io' \
  -H "Cookie: ridi-at=${TOKEN}"
```

6. If status is `200`, set the cookie in the locked browser tab and reload:

```text
browser_navigate url:
javascript:document.cookie='ridi-at=<at>; Domain=.local.ridi.io; Path=/; Secure; SameSite=Lax';location.reload()
```

7. Verify login state by navigating the same tab to `https://account.local.ridi.io/accounts/me` and checking `browser_network_requests` for a `200` main frame response.
8. Return the tab to its original local URL if it was on a local URL, then unlock the browser.

## Success Criteria

- `curl -sk https://account.local.ridi.io/accounts/me` with the token returns `200`.
- The same browser context receives `200` from `https://account.local.ridi.io/accounts/me`.
- The final response says login state is set, and mentions any unrelated page errors separately.

## Troubleshooting

- `401`: generate a new token and repeat. The previous token may be expired or not tied to the current `account.user_token`.
- `502` without `-k`: retry with `curl -sk` to separate local certificate/proxy issues from token validity.
- Preflight page `500`: login can still be complete if `accounts/me` is `200`; report the page error as separate from login state.
- Long-running token command: once JSON output is captured, terminate the leftover process if it does not exit on its own.

## Reference

- `.cursor/work-logs/event-participation-local-login-cookie.md`
