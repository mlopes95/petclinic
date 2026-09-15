## Why

GitHub issue #25 asks for an Owners grid that is sortable by column and paged in 5/10/20 rows.
Today `GET /api/owners` returns every owner as one array with nested pets *and* visits, and the
Angular list renders it all in a plain Bootstrap table. Bizu expects ~100.000 owners within a
year, so the current endpoint is a loaded gun and the UI has no way to page at all.

This proposal implements the decisions recorded in `Mici.md` (branch `kc26`). Every open
question there carried a recommendation; this change adopts each recommendation as-is.

## What Changes

**Backend**
- **BREAKING** `GET /api/owners` returns a Spring `Page<OwnerListItemDto>` (`content`,
  `totalElements`, `totalPages`, `number`, `size`) instead of a bare array. Never an unpaged list.
- New query parameters `page` (0-based), `size` (only 5, 10 or 20, default 10), `sort`
  (`NAME` | `CITY`, default `NAME`) and `dir` (`asc` | `desc`, default `asc`). Bound explicitly
  (inner `enum SortField` + Spring's `Sort.Direction`), not via `Pageable`. The existing
  `lastName` case-sensitive prefix filter is unchanged.
- `NAME` sorts `ORDER BY last_name, first_name, id`; `CITY` sorts `ORDER BY city, id`. The `id`
  tiebreak makes paging deterministic.
- Invalid `sort`, `dir` or `size` → 400 Problem Detail. Requires a new
  `@ExceptionHandler(MethodArgumentTypeMismatchException)` in `ExceptionControllerAdvice`
  (today a bad enum value would fall to the catch-all 500).
- New `OwnerListItemDto`: owner fields + `petNames: string[]`. Pet names are loaded with one
  explicit `findByOwnerIdIn(ids)` query per page and assembled in the mapper. `OwnerDto` (with
  pets and visits) stays as-is for `GET /api/owners/{id}`.
- Flyway `V9`: indexes `owners(last_name, first_name, id)` and `owners(city, id)`. The name
  index and the `ORDER BY` use the same ICU collation (`und-x-icu`) so `Śliwiński` sorts after
  `S`, not after `Z`; falls back to the default collation if ICU is unavailable in Zonky.
- Off-the-end page (`page=999`) → 200 with empty `content` and the true `totalElements`.
- `GET /api/owners/count` stays untouched (out of scope, `permitAll()` may have dependents).
- Regenerated in the same commit: `openapi.yaml`, `ApiExamples.OWNERS`.

**Frontend**
- Owners list becomes `MatTable` + `MatSort` + `MatPaginator` in server-side mode. Sort
  headers only on Name and City; page-size options 5/10/20; paginator wording stays English.
- `page`, `size`, `sort`, `dir` (and `lastName`) live in the URL query string
  (`/owners?page=3&size=20&sort=NAME&dir=desc`). The component reacts to
  `ActivatedRoute.queryParams` through a single `switchMap`, so out-of-order responses cannot
  paint stale rows. A new search resets to page 0 and keeps sort and size.
- New pure `ownerName` pipe under `shared/`, rendering `"Last, First"` (falling back to
  whichever part exists, no stray comma). Applied to every owner-name rendering (owner list,
  owner detail, pet add/edit, visit add/edit).
- The grid's fetch no longer swallows errors into `[]`; a failed page load surfaces via the
  existing snackbar interceptor instead of rendering "no owners".
- "No owners with LastName starting with X" keys off `totalElements === 0`, not `!owners`.
- Regenerated: `api-types.ts`; wiremock `get-api-owners.json` (already committed in the page
  shape, unused so far) gets the new field names; `OwnerPage` in `owner-page.ts` (committed,
  unused) becomes the type of the list response.

**Tests**
- Backend: MockMvc slice test covering paging, both sorts and directions, the `id` tiebreak,
  400 on bad `sort`/`dir`/`size`, empty off-the-end page, ICU ordering of `Ś`.
- Frontend: component spec for the URL ↔ grid binding and the search reset.
- e2e: new `owners-grid.feature` (sort Name asc/desc, sort City, change page size, walk the
  pages). `owner-search.feature.glue.ts` adapts: reads `data.content`, names as `"Last, First"`,
  Examples separator `,` → `;`, and "every owner is listed" walks all pages and asserts the union.
- A gitignored 100k-owner SQL generator plus a documented manual JMeter run proves the index is
  used; CI keeps its 28 seeded rows.

**Process**
- Post the decisions as a comment on issue #25, in particular that Name sorts last-name-first,
  which diverges from the outside contributor's claimed implementation.

## Capabilities

### New Capabilities
- `owners-list`: how the clinic lists owners — paged and sorted in the database, the page
  contract of `GET /api/owners`, sort fields and their ordering, size whitelist, error and
  edge-case behaviour, the grid's URL state, and the "Last, First" name rendering.

### Modified Capabilities
None — `openspec/specs/` is empty; the existing last-name prefix filter behaviour (pinned by
`owner-search.feature`) is carried into `owners-list` unchanged.

## Impact

- **API consumers of `GET /api/owners`** break: the Angular list, `owner-search.feature.glue.ts`,
  anything scripted against the array shape. The MCP owner resource and the chatbot are to be
  checked during implementation; nothing found grepping for the array shape beyond the above.
- **Backend**: `OwnerRestController`, `OwnerRepository`, `PetRepository`, `OwnerMapper`, new
  `OwnerListItemDto`, `ExceptionControllerAdvice`, `ApiExamples`, migration `V9`, `openapi.yaml`
  (generated by `OpenApiExtractorTest`; hand edits are denied).
- **Frontend**: `owners/owner-list/*`, `owner.service.ts`, `owners.module.ts` (Material table,
  sort, paginator imports), new `shared/owner-name.pipe.ts`, six templates rendering owner names,
  `generated/api-types.ts`, `wiremock/mappings/get-api-owners.json`.
- **Tests**: `petclinic-test/src/owner-search.feature.glue.ts`, new `owners-grid.feature` + glue,
  backend `OwnerTest`/new grid test, new component spec.
- **Guardrails** that will trip unless regenerated together: OpenAPI drift check, TS ↔ OpenAPI
  sync, Spectral lint, CODEOWNERS review on `openapi.yaml` and `db/migration/`.
- **Not touched**: `GET /api/owners/count`, `OwnerDto`, the `Owner.telephone` validation
  mismatch (separate ticket), keyset pagination (revisit at 10M rows).
