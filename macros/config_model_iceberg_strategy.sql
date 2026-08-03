{% macro config_model_iceberg_strategy(
    materialized_type="table",
    unique_key=None,
    incremental_strategy=None,
    partition_by=None,
    full_refresh=None,
    on_schema_change="sync_all_columns"
) %}
  {% set config_args = {
    "materialized": materialized_type,
    "table_format": "iceberg",
    "external_volume": "ICEBERG_EXTERNAL_VOLUME"
  } %}

  {% if materialized_type == "incremental" %}
    {% do config_args.update({
      "unique_key": unique_key,
      "incremental_strategy": incremental_strategy,
      "on_schema_change": on_schema_change
    }) %}
  {% endif %}

  {% if materialized_type == "table" and on_schema_change is not none %}
    {% do config_args.update({
      "on_schema_change": on_schema_change
    }) %}
  {% endif %}

  {% if partition_by is not none %}
    {% do config_args.update({
      "partition_by": partition_by
    }) %}
  {% endif %}

  {{ config(**config_args) }}
{% endmacro %}
