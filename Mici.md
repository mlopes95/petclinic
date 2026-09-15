# Mici.md — open questions for the Owners grid (GH #25)

Design notes for [issue #25](https://github.com/victorrentea/petclinic/issues/25)
("sortable by any column, pages of 5/10/20"), written to be argued with. Every open
question below carries a **recommendation** — the plan is to proceed on those unless
someone here makes a better case.

**The constraint that drives most of this:** Bizu expects **~100.000 owners within a
year**. The 28 seeded rows are a demo fixture, not the sizing.

---

## Already decided

| # | Decision | Why |
|---|---|---|
| 1 | Paging and sorting happen **in Postgres**, not in the browser | 100k rows |
| 2 | `GET /api/owners` returns **`Page<OwnerDto>`, always** | an endpoint that can return 100k rows in one array is a loaded gun |
| 3 | A page carries owner fields **+ pet names**, loaded by one batched query; `visits` dropped from the list response | the column is real info; nested visits never survive 100k |
| 4 | Sortable columns: **Name and City only** | real data: 9/28 addresses start with a house number, so `ORDER BY address` yields `14, 221B, 26, 4`; telephone has a NULL and mixed country prefixes |
| 5 | Grid = **MatTable + MatSort + MatPaginator** in server-side mode | accessible sort headers and a server-driven pager aren't worth hand-rolling |
| 6 | Names display and sort as **"Rentea, Victor"** → `ORDER BY last_name, first_name, id` | Romanian convention; app is deployed in .ro (confirmed with Bizu) |
| 7 | One **`ownerName` pipe**, applied to all owner name renderings (8 templates today) | "Potter, Harry" in the grid and "Harry Potter" on the detail page defeats the point |
| 8 | **page/size/sort live in the URL** (`/owners?page=3&size=20&sort=NAME&dir=desc`) | refresh keeps your place; links are shareable |
| 9 | Default page size **10** | 3 pages over the seeded 28 — visible in a demo, sane in production |
| 10 | The e2e scenario *"every owner in the clinic is listed"* **walks the pages** and asserts the union | keeps the original meaning *and* catches rows duplicated/skipped across pages |
| 11 | Exact `count(*)` for `totalElements` (no `Slice`, no estimate) | at 100k Postgres counts a filtered index in milliseconds |
| 12 | The `lastName` filter keeps its **case-sensitive prefix** semantics | `owner-search.feature` pins them |

---

## Open — Backend

### B1. Collation for the Name index
One seeded owner is `Śliwiński`. Under the DB's default collation `Ś` sorts **after `Z`**;
under an ICU/`pl` collation it sorts right after `S`. The index must be created with the
**same** collation as the `ORDER BY`, or Postgres cannot use it to sort at all — at 100k
that is the difference between an index scan and a full sort.

- (a) ICU collation (`und-x-icu`) on the index and the query
- (b) Leave the default and accept `Ś` after `Z`

**Recommendation: (a)** — a name grid whose alphabet is wrong is a bug users report.
⚠️ Tests run on Zonky embedded Postgres; verify ICU is available there, and wrap the
migration defensively (see B2) if not.

### B2. Migration `V9` and the embedded-Postgres trap
New indexes: `(last_name, first_name, id)` and `(city, id)`.
A past lesson: Flyway migrations using Postgres extensions must be wrapped in
`DO $$ BEGIN ... EXCEPTION WHEN OTHERS THEN ... END $$` or Zonky (which lacks `pg_trgm`,
and possibly ICU) breaks the whole test suite.

**Recommendation:** plain `CREATE INDEX` if ICU turns out unavailable in Zonky; otherwise
wrap the ICU variant with a fallback to the default collation.

### B3. How the sort parameters are bound
- (a) Explicit `?page=&size=&sort=&dir=`, with an inner `enum SortField { NAME, CITY }` and
  Spring's own `Sort.Direction`
- (b) Spring's `Pageable` argument resolver bound directly

**Recommendation: (a)**, matching the prior session's design. (b) accepts
`?sort=pets.visits.description` and turns it into a 500 or an unintended join; (a) is
self-documenting in `openapi.yaml` and rejects nonsense at the edge.
⚠️ Needs `@ExceptionHandler(MethodArgumentTypeMismatchException)` in
`ExceptionControllerAdvice` — **it does not exist yet**; without it a bad enum value
returns 500 instead of 400.

### B4. Is `size` free-form?
`?size=100000` re-arms the gun decision #2 disarmed.

- (a) Accept only 5 / 10 / 20; anything else → 400
- (b) Clamp silently to a max
- (c) Accept anything

**Recommendation: (a)** — the issue names exactly three sizes, so anything else is a client
bug worth surfacing. (b) hides it; (c) is an outage waiting for a typo.

### B5. Deep paging at 100k
`OFFSET 99.990` makes Postgres walk 100k index entries. Keyset ("seek") pagination fixes it
but cannot express "jump to page 4.812", which `MatPaginator` offers.

**Recommendation: keep OFFSET.** At 100k the worst page costs a few ms; revisit at 10M.
Listed here so nobody is surprised later.

### B6. How pet names get loaded
- (a) `@BatchSize` on `Owner.pets`
- (b) An explicit `findByOwnerIdIn(ids)` and assemble in the mapper

**Recommendation: (b)** — one visible, greppable query instead of a Hibernate annotation
whose effect only shows in the SQL log. `Owner.getPets()` already sorts by name, so the
displayed order is deterministic either way.

### B7. Does the list response get its own DTO?
Dropping `visits` from `OwnerDto` changes it for **every** consumer, including
`GET /api/owners/{id}` where visits are wanted.

- (a) New `OwnerListItemDto` for the paged list
- (b) Reuse `OwnerDto`, leave `visits` empty in list responses

**Recommendation: (a)** — (b) ships a field that is sometimes real and sometimes a lie,
which is the kind of thing a chatbot believes.

### B8. `GET /api/owners/count` — keep it?
`totalElements` now carries the same number. It's `permitAll()` while the rest of the
controller is `@PreAuthorize`, so something may depend on it.

**Recommendation: keep, untouched.** Out of scope for #25; deleting it is a separate,
deliberate decision.

### B9. Off-the-end pages
`?page=999` on a 3-page result.

**Recommendation:** 200 with empty `content` and correct `totalElements` — standard Spring
Data behaviour, and the UI already has to render "no results".

---

## Open — Frontend

### F1. Where the `ownerName` pipe lives, and what it does with gaps
`design-system/` currently holds only `combo`. What renders for an owner with no last name?

**Recommendation:** `shared/owner-name.pipe.ts` (pure pipe); output `"Last, First"`, falling
back to whichever part exists, with no stray comma. The design system is for widgets, not
formatting.

### F2. Racing requests
Clicking sort, then page 2 quickly, can land the responses out of order and paint stale rows.

**Recommendation:** funnel every grid fetch through one `switchMap` on a params subject —
the URL is already the single source of truth (decision #8), so the component reacts to
`ActivatedRoute.queryParams` and nothing else. Write with `replaceUrl: true` to avoid
polluting history on every keystroke.

### F3. What a new search does to page and sort
**Recommendation:** reset to page 0, keep sort and size. Staying on page 7 of a result set
that now has 2 pages is the classic "my search returned nothing" bug report.

### F4. Errors are currently swallowed
`OwnerService` maps failures to `[]` via `handlerError`, so a 500 renders as "no owners".
With paging it would have to fabricate an empty `Page`.

**Recommendation:** for the grid, let the error through and show it (the app already has
`MatSnackBar`). Fabricating an empty page turns an outage into a silent lie.
Bigger than #25 — flagging it, not fixing everything.

### F5. "No owners with LastName starting with X"
Today keyed off `!owners`. Must become `totalElements === 0` — otherwise it flashes on every
page change. Not a decision, just a trap; listed so it isn't forgotten.

### F6. MatPaginator wording
Ships as English ("Items per page"), inside a Bootstrap 3 page.

**Recommendation:** leave English. The rest of the UI is English; localising one widget is
worse than localising none.

---

## Open — Tests

### T1. Where the new scenarios live
Sort by Name asc/desc, sort by City, change page size, walk the pages.

- (a) A new `owners-grid.feature`
- (b) Append to `owner-search.feature`

**Recommendation: (a)** — the search feature is a tight spec about filter semantics;
paging assertions would drown it.

### T2. The four forced edits to `owner-search.feature.glue.ts`
Not decisions, but all four must land together or the suite is red:
`Array.isArray(data)` on the list response; `fullName` → "Last, First";
`namesIn` splits on `,` which now collides with the name format (**switch the separator to
`;`**); and the "every owner" step must walk pages.

### T3. Proving the index at 100k
CI seeds 28 rows, so nothing here can fail when the sort goes unindexed.

- (a) A gitignored SQL generator + a manual JMeter run, documented
- (b) Seed 100k in CI
- (c) Nothing

**Recommendation: (a)** — (b) makes every CI run pay for a scenario that changes once a
year; (c) means we find out in production.

### T4. Order of work (TDD)
**Recommendation:** backend slice test (paging, sorting, the `id` tiebreak, 400 on a bad
sort field) → implementation → frontend component spec → Playwright e2e last.
⚠️ Never run a partial suite (`-Dtest=X`) after a full run before committing: it overwrites
`jacoco.csv` with partial coverage and the commit hook blocks.

---

## Open — Process

### P1. Regenerated artefacts
`openapi.yaml`, the generated `api-types.ts`, the wiremock mapping
`get-api-owners.json`, and `ApiExamples.OWNERS` all encode the array shape and must be
regenerated in the same commit, or the guardrail tests fail.

### P2. Reply on the issue
The issue already has a comment from an outside contributor claiming this is implemented
(MatTable + Pageable, sorting by firstName and city).

**Recommendation:** post the decisions above as a comment on #25 — in particular that Name
sorts **last-name-first** here, which is where our design and theirs diverge.

---

## Not part of #25, found while digging

`Owner.telephone` is annotated `@NotEmpty @Pattern(regexp = "^[0-9]{10}$")` — "exactly 10
digits" — yet the seeded data holds 13-digit numbers (`0442079372121`) and one NULL
(Kevin McCallister, cleared by `V5__clear_demo_owner_phone.sql`). The entity's own
validation contradicts the data it ships with. Worth its own ticket.
