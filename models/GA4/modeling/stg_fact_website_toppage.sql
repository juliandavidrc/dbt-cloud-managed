{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date'
) }}

WITH stg_base_events AS (
  SELECT 
    event_name,
    ga_session_id,
    event_params,
    ga_session_number,
    user_pseudo_id,
    is_active_user,
    session_engaged,
    unique_id,
    event_date,
    event_timestamp,
    lead_type,
    step_name,
    step_number,
    page_location,
    geo_country,
    page_title,
    page_title_english,

    COALESCE(
      session_traffic_source_last_click_cross_channel_campaign_default_channel_group,
      session_traffic_source_last_click_cross_channel_campaign_primary_channel_group,
      'Unassigned'
    ) AS traffic_category,

    COALESCE(
      traffic_source_name,
      collected_traffic_source_manual_campaign_name,
      session_traffic_source_last_click_cross_channel_campaign_campaign_name,
      session_traffic_source_last_click_manual_campaign_campaign_name,
      'Unassigned'
    ) AS campaign_name,

    COALESCE(
      traffic_source_medium,
      collected_traffic_source_manual_medium,
      session_traffic_source_last_click_manual_campaign_medium,
      session_traffic_source_last_click_cross_channel_campaign_medium,
      'Unassigned'
    ) AS campaign_medium,

    COALESCE(
      traffic_source_source,
      collected_traffic_source_manual_source,
      session_traffic_source_last_click_manual_campaign_source,
      session_traffic_source_last_click_cross_channel_campaign_source,
      'Unassigned'
    ) AS campaign_source,

    UUID_STRING('e90fa283-e222-4794-9281-7c18ea80fefa', geo_country) AS country_id,
    UUID_STRING('60962c40-c6a8-47f6-956b-63a1cf23dea8', traffic_category) AS traffic_category_id,
    UUID_STRING('7d194f30-375f-4e79-91cd-781665e71811', campaign_name) AS campaign_name_id,
    UUID_STRING('0f5bcffd-8858-4e7f-864a-2790f7001add', campaign_medium) AS campaign_medium_id,
    UUID_STRING('343eca5c-9666-40f8-9b15-51ecac319fae', campaign_source) AS campaign_source_id
  FROM {{ source("GA4_silver", "dim_events_flat") }}    
  {% if is_incremental() %}
    WHERE event_date >= DATEADD(day, -3, CURRENT_DATE)
  {% endif %}
  
),

stg_table AS (
  SELECT
    event_date,
    country_id,
    traffic_category_id,
    campaign_name_id,
    campaign_medium_id,
    campaign_source_id,
    
    CASE
        WHEN LENGTH(page_title_english) > 0 THEN page_title_english
        ELSE COALESCE(page_title, 'Unassigned')
    END AS cm_page_title,
    count(distinct ga_session_id)  AS cm_visits_number
  FROM stg_base_events
  WHERE event_name = 'page_view'
  GROUP BY event_date, country_id, traffic_category_id, campaign_name_id, campaign_medium_id, campaign_source_id, cm_page_title
)

SELECT *,
    UUID_STRING('81880b66-7273-403d-87eb-455412333cc8', ' - ' || event_date || 
                                                        ' - ' || country_id || 
                                                        ' - ' || traffic_category_id || 
                                                        ' - ' || campaign_name_id || 
                                                        ' - ' || campaign_medium_id || 
                                                        ' - ' || campaign_source_id ||
                                                        ' - ' || cm_page_title) as unique_id,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
FROM stg_table