{{
  config(
    materialized = 'incremental'
    )
}}


SELECT * FROM {{ source('staging', 'listings') }}

{% if is_incremental() %}

where created_at >= (select coalesce(max(created_at),'2020-01-01') from {{ this }} )

{% endif %} 