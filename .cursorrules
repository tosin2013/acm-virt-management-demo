# Agent Instructions

This file gives the AI agent persistent rules across sessions.

<!-- PMB-RULES-START (managed by `pmb connect`) -->
## PMB - persistent memory (via MCP)

This project has a PMB workspace attached. The user reviews your
adherence to these rules in the PMB dashboard's "Adherence" tab; your
prepare-rate, lesson-followthrough, and read/write ratio are visible
to them. Skipping the rules below means writing into a void the user
can see is unused.

### REQUIRED - call BEFORE the first substantive action of any task

```
prepare(message="<the user's first or current message>")
```

That single call returns project_context, surfaced lessons (with
`surface_id`), recent_activity, open_goals. ~10 ms. If the response
has a `lessons` array, READ THEM before acting - they OVERRIDE your
defaults ("use pnpm not npm" means use pnpm, no debate).

After acting on a surfaced lesson:

```
mark_lesson_followed(surface_id=<from prepare>, followed=True|False,
                     applicable=True|False,
                     note="<one line: what you did>")
```

Use applicable=False when the lesson was unrelated to the task. Use
followed=False only when it applied but you deliberately did not follow it.
Lessons never marked remain unknown.

When recording a project-specific lesson via record_batch, include
`"project":"<project name>"`. Omit `project` only for genuinely global rules.

### OK to skip prepare() ONLY when

- User asks a pure theory question ("what is X / how does Y work")
  with no project context. Answer from training.
- Continuation of a task already prepared earlier this session.
- One-line trivial change (rename a variable, fix a typo).

If you're unsure - call prepare(). It's 10 ms.

### BEFORE a kind of action you haven't done before this session

Before introducing a tool / library / pattern / config / command you
have NOT already used in this session, CHECK memory first:

```
find_lessons(query="<what you're about to do>")     # rules / gotchas
recall(query="<what you're about to do>")           # past decisions / why
```

Then:
- A lesson or past decision covers it → FOLLOW it. Don't re-litigate a
  settled call without a concrete new reason.
- Nothing comes back → proceed with your best judgement, AND record the
  choice so the next session doesn't start from zero:
  `record_batch(items=[{"type":"activity","kind":"decision",
   "content":"Chose X for <task> because <reason>; no prior memory on it"}])`

This is the loop that makes the agent get better at THIS project over
time: act → record why → next time it surfaces as a decision/lesson.

### Context that arrives automatically (PMB hooks)

If PMB hooks are installed you'll sometimes see, prepended to a message,
blocks titled `== PMB auto-context ==` or `== PMB session restore ==`.
That's PMB pre-loading memory for you - treat its lessons/decisions as
if you'd fetched them yourself. After a compaction, the session-restore
block tells you what THIS session already did: pick the thread back up,
don't re-ask the user.

### WRITE - one `record_batch` per turn, only on these triggers

| Trigger | What to write |
| --- | --- |
| "remember / this is important" | fact, importance=0.95, pin=true |
| User shares a personal fact | fact, importance=0.7 |
| You completed substantive work | activity, kind=completed |
| You made a project-shaping choice | activity, kind=decision |
| User corrected you OR a non-obvious rule emerged | lesson (high-importance) |
| User states a personal attribute that CAN CHANGE | record_keyed_fact(subject, attribute, value) |
| FUTURE intent - "next we'll do X / the plan is …" | goal (record_goal or batch {"type":"goal"/"plan", status="pending"}), NOT a fact |

Never call `recall` after writing to "verify". Never call `pin`
separately. Use absolute dates ("On May 25, 2026"), not "today".

### Anti-patterns the user watches for

- ❌ Writing 3 lessons in one session without calling prepare once.
  → looks like LARP, not memory use.
- ❌ Long boilerplate "I'll save this..." narration.
  → the user does not read it; tools already returned.
- ❌ Marking lessons followed=True without a `note`.
  → looks like compliance theatre.
- ❌ Calling recall(...) with a 1-2 word query.
  → use prepare(message=full_user_text) instead.

### Style

Use read results as your own knowledge - weave naturally. Never say
"I found in memory / according to the records / I recorded that". Don't
narrate which tools you called.

PMB is local-only. Apache 2.0. The user owns every byte.

<!-- PMB-RULES-END -->
