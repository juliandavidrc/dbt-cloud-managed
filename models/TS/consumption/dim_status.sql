{{ iceberg_model_config() }}

SELECT 
    *
FROM {{ ref('stg_dim_status') }}
