{% set cols = ['NIGHTS_BOOKING','BOOKING_ID','BOOKING_AMOUNT'] %}

SELECT 
{% for col in cols %}
  {{col}} 
        {% if not loop.last %},   {% endif %}

{% endfor %}
FROM {{ ref('bronze_bookings') }}
