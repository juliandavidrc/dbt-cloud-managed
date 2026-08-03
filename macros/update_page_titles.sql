{% macro update_page_titles() %}
    {% set sql %}
        UPDATE {{ ref('dim_flattened_events') }} AS a
        SET 
            page_title_english = b.page_title_english,
            page_title_spanish = b.page_title_spanish
        FROM {{ ref('int_pivot_page_title') }} AS b
        WHERE TRIM(a.page_title) = TRIM(b.page_title);
    {% endset %}

    {% do run_query(sql) %}
{% endmacro %}