/*
    Model Name: messages_split
    Model Goal: Transform data from the chat history table `DEV_LANDING.DEV_LANDING_CHAT_HISTORY.MESSAGES` 
                to parse and structure columns in the desired format for downstream analytics and reporting.
    
    Description:
    - This model is designed to extract all relevant columns from the `MESSAGES` table.    
    - The model is materialized as a view, meaning it will not store data physically but will act as a virtual table.    

    Notes:
    - You can change the materialization type (e.g., 'view', 'table', 'incremental').
*/
{{
 config(
     materialized = "view",
     database = env_var('DBT_ENVIRONMENT') ~ '_MODELING',
     schema = env_var('DBT_ENVIRONMENT') ~ '_MODELING_CHAT_HISTORY'
)}}

SELECT 
    "Name",
    "Webex_Chat_ID",
    "Message_Direction",
    "Message_Type",
    "Livechat_Type",
    "Whatsapp_Type",
    "List_Response",
    "Time_Response",
    "Template_ID",
    "Message",    
    SPLIT_PART(REGEXP_SUBSTR("Message", 'Customer ID: \\*?\\*?(.*?)\\*?\\*?'), 'Customer ID: ', 2) AS Customer_id,
    SPLIT_PART(REGEXP_SUBSTR("Message", 'Email: ([\\w.%+-]+@[\\w.-]+)'), 'Email: ', 2) AS Email,
    "Ingestion_Timestamp",
    "Ingestion_UUID"
FROM {{ source('Chat_History', 'MESSAGES_ICEBERG') }}