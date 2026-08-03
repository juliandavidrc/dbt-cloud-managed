{{ iceberg_model_config() }}

SELECT 
    *
FROM {{ ref('stg_chat_history_messages') }}