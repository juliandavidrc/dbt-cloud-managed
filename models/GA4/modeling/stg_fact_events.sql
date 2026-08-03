{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date'
) }}

WITH stg_events_data AS (
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

    geo_country,
    geo_region,
    geo_sub_continent,
    geo_continent
    FROM {{ source("GA4_silver", "dim_events_flat") }},
{% if is_incremental() %}
WHERE event_date >= DATEADD(day, -3, CURRENT_DATE)
{% endif %}
),

stg_enriched_data AS (
  SELECT
    td.*,
    UUID_STRING('e90fa283-e222-4794-9281-7c18ea80fefa', td.geo_country) AS country_id,
    UUID_STRING('60962c40-c6a8-47f6-956b-63a1cf23dea8', td.traffic_category) AS traffic_category_id,
    UUID_STRING('7d194f30-375f-4e79-91cd-781665e71811', td.campaign_name) AS campaign_name_id,
    UUID_STRING('0f5bcffd-8858-4e7f-864a-2790f7001add', td.campaign_medium) AS campaign_medium_id,
    UUID_STRING('343eca5c-9666-40f8-9b15-51ecac319fae', td.campaign_source) AS campaign_source_id,
    s.cm_session_id,
    s.cm_session_engaged
  FROM stg_events_data td
  LEFT JOIN {{ ref('stg_calc_metrics_sessions') }} s ON td.unique_id = s.unique_id
)

SELECT
  unique_id,
  user_pseudo_id,  
  event_date,
  event_timestamp,
  ga_session_id,
  cm_session_id,
  cm_session_engaged,
  event_params,
  geo_country,
  traffic_category,
  campaign_name,
  campaign_medium,
  campaign_source,  
  country_id,
  traffic_category_id,
  campaign_name_id,
  campaign_medium_id,
  campaign_source_id,
  cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date,

  CASE 
    WHEN event_name = 'session_start' THEN ga_session_id 
    ELSE NULL 
  END AS sessions_number,

  CASE
    WHEN event_name = 'user_engagement'
      AND is_active_user = TRUE
      AND session_engaged = 1
    THEN user_pseudo_id
    ELSE NULL
  END AS active_users,

  CASE
    WHEN event_name = 'first_visit'
      AND ga_session_number = 1
    THEN user_pseudo_id
    ELSE NULL
  END AS new_users,
  
  CASE
    WHEN event_name = 'generate_lead'      
    THEN user_pseudo_id
    ELSE NULL
  END AS form_Completion,

  CASE
    WHEN event_name = 'newsletter_subscription'      
    THEN user_pseudo_id
    ELSE NULL
  END AS subscription_users,

  CASE
    WHEN event_name = 'book_your_stay'      
    THEN user_pseudo_id
    ELSE NULL
  END AS lead_passes

FROM stg_enriched_data
