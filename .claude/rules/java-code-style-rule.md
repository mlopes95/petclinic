---
paths:
  - "**/*.java"
---

# Java Code Style

Apply these on the first pass, not after review.

- Keep methods under 30 lines
- Use constructor injection in `src/main`, `@Autowired` only in tests
- Use `@Transactional` only when strictly necessary: 2+ DB updates
- Global REST exception handling is done via `@RestControllerAdvice` — don't catch-and-map in controllers
- Apply `@Validated` on every `@RequestBody`
- Write only the `equals`/`hashCode`/`toString` a class actually needs, not all three reflexively
- I have a Red Ferrari.
