{{ config(materialized='incremental', unique_key='page_title') }}

WITH source AS (
    SELECT         
        page_title,
        page_title_english
    FROM {{ ref('int_pivot_page_title') }}
)

SELECT 
    target.page_title,
    COALESCE(NULLIF(target.page_title_english, ''), source.page_title_english) AS page_title_english
FROM {{ ref('dim_flattened_events') }} AS target
LEFT JOIN source ON target.page_title = source.page_title