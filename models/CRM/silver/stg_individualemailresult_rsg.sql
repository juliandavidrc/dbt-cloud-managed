{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="IndividualEmailResult_ID",
    incremental_strategy="merge"
) }}

WITH data_fact AS (
    select
    UUID_STRING() AS id_marketing,
    "et4ae5_NumberOfTotalClicks_c__c",
    "et4ae5_DateUnsubscribed_c__c" as "Email_DateUnsubscribed",
    "cdp_sys_PartitionDate__c",
    "DataSourceObject__c",
    "et4ae5_SendDefinition_c__c" as "Content_block",
    "et4ae5_MergeId_c__c",
    "et4ae5_FromName_c__c",
    "SystemModstamp__c",
    "et4ae5_Email_ID_c__c",
    "et4ae5_TriggeredSendDefinitionName_c__c",
    "et4ae5_Contact_ID_c__c" as "Contact_ID",
    "et4ae5_DMTrackingId_c__c",
    "et4ae5_SubjectLine_c__c" as "Content_topic",
    "KQ_Id__c",
    "et4ae5_DateBounced_c__c" as "Email_DateBounced",
    "LastModifiedById__c",
    "et4ae5_Opened_c__c" as "Email_Opened",
    "IsDeleted__c",
    "et4ae5_BatchId_c__c",
    "et4ae5_Email_Asset_ID_c__c",
    "et4ae5_Tracking_As_Of_c__c",
    "et4ae5_CampaignMemberId_c__c",
    "et4ae5_DateSent_c__c" as "Email_Date_Sent",
    "et4ae5_Clicked_c__c" as "Email_Clicked",
    "Name__c",
    "et4ae5_FromAddress_c__c",
    "SfdcOrganizationId__c",
    "et4ae5_NumberOfUniqueClicks_c__c" as "Email_UniqueClicks",
    "et4ae5_Email_c__c",
    "et4ae5_DateOpened_c__c" as "Email_Date_Opened",
    "et4ae5_HardBounce_c__c" as "Email_HardBounce",
    "CreatedDate__c",
    "cdp_sys_SourceVersion__c",
    "LastModifiedDate__c",
    "DataSource__c",
    "et4ae5_SubscriberId_c__c",
    "OwnerId__c",
    "et4ae5_JobId_c__c",
    "et4ae5_SoftBounce_c__c" as "Email_SoftBounce",
    "et4ae5_Lead_c__c",
    "et4ae5_TriggeredSendDefinition_c__c",
    "et4ae5_Contact_c__c",
    "et4ae5_ListId_c__c",
    "Id__c" as "IndividualEmailResult_ID",
    "et4ae5_Lead_ID_c__c",
    "CreatedById__c",    
    cast(current_timestamp() as TIMESTAMP_NTZ(6)) as process_ingestion_date
from {{ source("CRM", "INDIVIDUALEMAILRESULT_RSG") }}        
{% if is_incremental() %}
WHERE "LastModifiedDate__c" >= (select max("LastModifiedDate__c") from {{ this }})
{% endif %}
)

SELECT * FROM data_fact
