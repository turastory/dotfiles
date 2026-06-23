# Event Detail GraphQL Notes

Use this when working on event detail GraphQL operations or books-islands event detail rendering.

## Operation Split

Event detail islands can split metadata and user-progress data into separate GraphQL operations:

- SSR metadata is commonly loaded from `frontends/web/shared/gql-client-codegen/query/eventDetail/eventDetailMetadata.graphql`.
- Participation user progress can be loaded separately from `frontends/web/shared/gql-client-codegen/query/eventDetail/eventDetailEventParticipationUserProgress.graphql`.

Before relying on a screen-level e2e result, inspect the actual operation file and the books-islands consumer. Adding a union member or resolver field does not guarantee the UI renders every `__typename`.

## Related References

- For event participation tables and mission-derived progress rules, read `../../ridi-db-schema/references/domain-map.md`.
