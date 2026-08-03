{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"
) }}

with
    table_campaign_medium as (
        select distinct
            coalesce(
                traffic_source_medium,
                collected_traffic_source_manual_medium,
                session_traffic_source_last_click_manual_campaign_medium,
                session_traffic_source_last_click_cross_channel_campaign_medium,
                'Unassigned'
            ) as campaign_medium
        from {{ source("GA4_silver", "dim_events_flat") }}
    )
select
    uuid_string(
        '0f5bcffd-8858-4e7f-864a-2790f7001add', campaign_medium
    ) as campaign_medium_id,
    campaign_medium,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_campaign_medium
