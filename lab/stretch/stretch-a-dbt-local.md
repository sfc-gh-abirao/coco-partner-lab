# Stretch A — dbt via CoCo's local execution mode

**15–20 min. Needs `FULL` or `CORE`, and Core B finished.**

Port your Core B pipeline into a dbt project and run it through CoCo.

---

## Why local mode rather than dbt Projects on Snowflake

dbt Projects on Snowflake is the better production answer, but standing it up
needs an API integration, a Git repository, optionally a secret, a network rule,
and an external access integration before the first `dbt deps` runs. That is the
whole stretch slot spent on setup.

CoCo has a **Toggle dbt Execution Mode** command that switches between
Snowflake-managed and local execution. Local mode runs the project from your
machine against your Snowflake connection, which gets you the authoring and
compile experience immediately.

The deployment path is at the bottom of this page as homework, with the privilege
list, so you know what to scope when a customer asks for it.

---

## Steps

### 1. Point dbt at your schema

`dbt_starter/` has a skeleton. Create `profiles.yml` from
`profiles.yml.example`, setting your account, warehouse, and the `ENG_*` schema
`01_setup.sql` created for you.

`profiles.yml` is gitignored. Keep it that way.

### 2. Port your models

Move your Core B staged and curated layers into `dbt_starter/models/`.

The interesting part is the dynamic tables. Two options, and the choice is the
exercise:

- **`materialized='dynamic_table'`** with `snowflake_warehouse`, `target_lag`,
  and **`refresh_mode='incremental'`** in the model config
- Leave them as raw DDL outside dbt, as `legacy_project/` does

`legacy_project/models/dynamic/` took the second route and disabled the
directory in `dbt_project.yml`. Read the comment there — it was a
time-constraint decision that became permanent. That is worth noticing, because
it is the kind of decision you will be asked to unpick on an engagement.

### 3. Run it

**Toggle dbt Execution Mode** → Local. Then:

```
dbt deps
dbt compile
dbt run --select staged+
```

Use **View Compiled SQL** on a model to see what dbt generated. On a dynamic
table model, check the compiled DDL actually contains your `REFRESH_MODE`. If it
does not, your config is not doing what you think.

### 4. Carry the rule across

Add the `REFRESH_MODE` rule to your Core C skill as a **dbt config** rule, not
just a SQL one. The rule is the same; where it has to be written is different.
A standard that only covers hand-written DDL will silently not apply to the dbt
models, which is where most of the customer's pipeline actually lives.

---

## Checkpoint

- `dbt run` succeeds against your schema
- `SHOW DYNAMIC TABLES` shows `refresh_mode = INCREMENTAL` on anything dbt created
- Your skill covers both the DDL and the dbt config form of the rule

---

## Homework: deploying properly

To run this as a `DBT PROJECT` object on Snowflake, you need:

| | |
|---|---|
| `CREATE DBT PROJECT` on the schema | To create the object |
| `USAGE` on the dbt project object | To execute it, list files, see history |
| `MONITOR` on the object | For run history and artifact retrieval functions |
| An API integration | To reach the Git provider |
| A secret | Only if the repository is private |
| A network rule + external access integration | For `dbt deps` to fetch packages |

Worth knowing before you quote it: the deploy role and the role in the profile
target can differ, and execution is restricted to the intersection of the calling
user's privileges and the profile role's. That catches people out.
