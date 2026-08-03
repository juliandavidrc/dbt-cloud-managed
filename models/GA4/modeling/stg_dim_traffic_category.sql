{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"
) }}

with
    table_traffic_category as (
        select distinct
            coalesce(
                session_traffic_source_last_click_cross_channel_campaign_default_channel_group,
                session_traffic_source_last_click_cross_channel_campaign_primary_channel_group,
                'Unassigned'
            ) as traffic_category
        from {{ source("GA4_silver", "dim_events_flat") }}
    )
select
    uuid_string(
        '60962c40-c6a8-47f6-956b-63a1cf23dea8', traffic_category
    ) as traffic_category_id,
    traffic_category,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_traffic_category
