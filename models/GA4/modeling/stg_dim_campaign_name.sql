{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"
) }}

with
    table_campaign_name as (
        select distinct
            coalesce(
                traffic_source_name,
                collected_traffic_source_manual_campaign_name,
                session_traffic_source_last_click_cross_channel_campaign_campaign_name,
                session_traffic_source_last_click_manual_campaign_campaign_name,
                'Unassigned'
            ) as campaign_name
        from {{ source("GA4_silver", "dim_events_flat") }}
    )
select
    uuid_string(
        '7d194f30-375f-4e79-91cd-781665e71811', campaign_name
    ) as campaign_name_id,
    campaign_name,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_campaign_name
