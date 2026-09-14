{% macro proper_name(col, node) %}
  {{col | trim | upper}}
{% endmacro %}