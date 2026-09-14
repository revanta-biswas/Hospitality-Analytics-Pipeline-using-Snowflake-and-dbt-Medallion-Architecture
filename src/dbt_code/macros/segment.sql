{% macro segment(col) %}
  CASE 
    WHEN {{ col }} < 100 THEN 'Budget'
    WHEN {{ col }} >= 100 AND {{ col }} < 200 THEN 'Mid-range'
    ELSE 'Luxury'
  END
{% endmacro %}