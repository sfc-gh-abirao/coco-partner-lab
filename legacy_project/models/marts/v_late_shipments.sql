/*
    Late shipments for the ops standup. Ops asked for this today so it is not
    pretty.

    DP 2023-08-02
*/

select
    s.shipment_id,
    s.order_id,
    s.carrier_id,
    (select carrier_name from {{ ref('stg_carriers') }} c
      where c.carrier_id = s.carrier_id)            as carrier_name,
    s.destination_postal_code,
    s.shipped_at,
    s.promised_delivery_at,
    s.actual_delivery_at,
    datediff('hour', s.promised_delivery_at, s.actual_delivery_at) as hours_late,
    case
        when datediff('hour', s.promised_delivery_at, s.actual_delivery_at) > 72 then 'SEVERE'
        when datediff('hour', s.promised_delivery_at, s.actual_delivery_at) > 24 then 'MAJOR'
        else 'MINOR'
    end                                             as lateness_band
from {{ ref('stg_shipments') }} s
where s.actual_delivery_at > s.promised_delivery_at
  and s.status = 'DELIVERED'
