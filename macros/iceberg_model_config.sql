{% macro iceberg_model_config(
    materialized_type="table",
    unique_key=None,
    incremental_strategy=None,
    partition_by=None,
    full_refresh=None
) %}
  {% set external_volume = env_var('DBT_SNOWFLAKE_EXTERNAL_VOLUME') %}
  
  {% set config_args = {
    "materialized": materialized_type,
    "table_format": "iceberg",
    "external_volume": external_volume
  } %}

  {% if materialized_type == "incremental" %}
    {% do config_args.update({
      "unique_key": unique_key,
      "incremental_strategy": incremental_strategy
    }) %}
  {% endif %}

  {% if partition_by is not none %}
    {% do config_args.update({
      "partition_by": partition_by
    }) %}
  {% endif %}

  {{ config(**config_args) }}
{% endmacro %}