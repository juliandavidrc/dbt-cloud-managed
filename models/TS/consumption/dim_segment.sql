{{ iceberg_model_config() }}

SELECT 
    SEGMENT_ID,
    SEGMENT_NAME
FROM {{ ref('stg_dim_segment') }}