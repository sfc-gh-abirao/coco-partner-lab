{#
    Standard money rounding. Finance wants 2dp everywhere.
#}
{% macro money(column_name) %}
    round({{ column_name }}, 2)
{% endmacro %}


{#
    Post-migration filter. Pre-July-2023 rows came from SQL Server with
    unreliable timestamps.

    Not every model uses this, which is not deliberate.
#}
{% macro post_migration(timestamp_column) %}
    {{ timestamp_column }} >= '{{ var("migration_cutoff_date") }}'
{% endmacro %}


{#
    Late-shipment predicate. Defined here so the definition of "late" lives in
    one place.

    Defined, then not used — v_late_shipments and fct_shipments each inline
    their own version of this.
#}
{% macro is_late(promised_column, actual_column) %}
    {{ actual_column }} > {{ promised_column }}
{% endmacro %}
