# Stretch C — CoWork readiness

**15–20 min. Needs `FULL` or `CORE` plus Tier 4 grants, and Core B finished.**

Build the layer that sits between your pipeline and a CoWork agent, and find out
where the real work is.

---

## The point of this exercise

In the walkthrough we said the semantic view is the product — that a CoWork agent
is only as good as the model underneath it. This is where you test that claim
against your own curated table.

You may not finish a working agent in twenty minutes. That is fine. The
deliverable is knowing **what a customer is actually buying** when they ask for
"AI on our data", because you will be scoping it.

---

## 1. Semantic view over your curated model (10 min)

Create a semantic view on your Core B curated layer. It needs:

- **Entities** — customer, order. What the business talks about.
- **Metrics** — `revenue_amount` at minimum, with the aggregation defined
  explicitly and at the correct grain.
- **Dimensions** — a date dimension, or "last month" cannot resolve.
- **Synonyms** — what does your customer call revenue? Turnover? Net sales?
  Billings? If they say "turnover" and your view says "revenue", the agent will
  not find it.

Use the `agent-studio` skill.

### The question that matters

Write your metric definition down in one sentence, in business language.

If you cannot, the agent cannot answer questions about it reliably — and neither
can the customer's finance team, which is usually why the numbers do not tie in
the first place. Ambiguity in a metric definition does not get resolved by AI, it
gets amplified by it.

---

## 2. Point it at the broken model, then don't (5 min)

**Thought experiment, not an implementation step.** Do not actually build this.

Suppose the semantic view sat on `V_REVENUE_BY_CUSTOMER_PRODUCT` — the fanout
view from `03_broken_artifacts.sql`.

Every revenue question in CoWork would return a figure roughly **2.94x** too
high. It would arrive with a chart. It would be traceable to a query that looks
entirely reasonable. Nothing would be flagged.

There is no agent instruction, prompt, or verified answer that fixes this. The
only fix is upstream.

Write down, in one line, what you would tell a customer who asked why they need
to pay for the modelling work before the AI work. You will need that sentence.

---

## 3. Agent, and the grants (5 min)

If you have Tier 4 grants, create an agent with Cortex Analyst over your semantic
view and ask it one question.

Then write down the grant list a customer's admin would need, because this is the
part that stalls engagements:

| | |
|---|---|
| `USAGE` on the agent | To query it |
| `USAGE` on database and schema | To see the objects behind it |
| `USAGE` on the semantic view | Cortex Analyst reads it |
| `SELECT` on the underlying tables | The generated SQL runs as the asking user |
| `USAGE` on the CoWork object | Controls which agents a user sees |
| `SNOWFLAKE.CORTEX_AGENT_USER` | If Cortex was revoked from `PUBLIC` |

Two things worth knowing cold, because a customer's security team will ask:

- Queries run with **the asking user's** credentials. Row-access and masking
  policies apply automatically. You do not reimplement governance in the agent.
- Users need a **default role and default warehouse** set, or their first CoWork
  session starts with them having to pick both.

---

## Checkpoint

You can answer these without looking anything up:

1. What makes a semantic view good rather than merely present?
2. Why can't a prompt fix a grain error in the model beneath it?
3. What grants does a customer need, and which is the one people forget?
4. Who on the customer's side has to own the metric definitions?

Question 4 is the one that decides whether the engagement goes well. It is not an
engineering question, and it is not yours to answer alone.
