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

stg_classified_leads AS (
  SELECT
    event_date,
    country_id,
    traffic_category_id,
    campaign_name_id,
    campaign_medium_id,
    campaign_source_id,    
    
    lead_type AS cm_lead_type,
    
    CASE
      WHEN lead_type = 'contact_form' THEN 'Contact Us'
      WHEN lead_type = 'newsletter' THEN 'Newsletter Subscription'
      WHEN lead_type = 'enquiry_form' THEN 'Enquiry'
      ELSE 'Unassigned'    
    END AS cm_lead_type_name,
    
    COUNT_IF(step_name = 'form_success') AS cm_total_form_successes,
    
    COUNT_IF(step_number = 0) AS cm_total_number_impressions
    
  FROM stg_base_events
  WHERE event_name = 'form_fulfillment'
    AND lead_type NOT IN ('campaign_form', 'interest_form')
  GROUP BY event_date, country_id, traffic_category_id, campaign_name_id, campaign_medium_id, campaign_source_id, cm_lead_type, cm_lead_type_name

  UNION ALL

  SELECT
    event_date,
    country_id,
    traffic_category_id,
    campaign_name_id,
    campaign_medium_id,
    campaign_source_id,    
    
    IFNULL(lead_type, 'campaign_form') as cm_lead_type,    
    
    'Campaigns' AS cm_lead_type_name,    
    
    COUNT_IF(step_name = 'form_success' AND event_name = 'form_fulfillment' AND lead_type = 'campaign_form') AS cm_total_form_successes,
    
    COUNT_IF(event_name = 'page_view' AND page_location ILIKE '%experience_more%') AS cm_total_number_impressions
  FROM stg_base_events
  WHERE (
    (event_name = 'form_fulfillment' AND lead_type = 'campaign_form' AND step_name = 'form_success' AND page_location ILIKE '%experience_more%')
    OR (event_name = 'page_view' AND page_location ILIKE '%experience_more%')
  )
  GROUP BY event_date, country_id, traffic_category_id, campaign_name_id, campaign_medium_id, campaign_source_id, cm_lead_type, cm_lead_type_name

  UNION ALL

  SELECT
    event_date,
    country_id,
    traffic_category_id,
    campaign_name_id,
    campaign_medium_id,
    campaign_source_id,    
    
    IFNULL(lead_type, 'interest_form') AS cm_lead_type,
    
    'Residential' AS cm_lead_type_name,    
    
    COUNT_IF(step_name = 'form_success' AND event_name = 'form_fulfillment' AND lead_type = 'interest_form') AS cm_total_form_successes,
    
    COUNT_IF(event_name = 'page_view' AND page_location ILIKE '%residential%') AS cm_total_number_impressions
  FROM stg_base_events
  WHERE (
    (event_name = 'form_fulfillment' AND lead_type = 'interest_form' AND step_name = 'form_success' AND page_location ILIKE '%residential%')
    OR (event_name = 'page_view' AND page_location ILIKE '%residential%')
  )
  GROUP BY event_date, country_id, traffic_category_id, campaign_name_id, campaign_medium_id, campaign_source_id, cm_lead_type, cm_lead_type_name
)

SELECT *,
    UUID_STRING('4997538b-005d-45e9-b786-318f6cbc024f', ' - ' || event_date || 
                                                        ' - ' || country_id || 
                                                        ' - ' || traffic_category_id || 
                                                        ' - ' || campaign_name_id || 
                                                        ' - ' || campaign_medium_id || 
                                                        ' - ' || campaign_source_id ||
                                                        ' - ' || cm_lead_type ||
                                                        ' - ' || cm_lead_type_name) as unique_id,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
FROM stg_classified_leads