-- answers to question part 2a

-- 1. determining the most ordered item based on successfully checked-out carts:

-- creating a common table expression (CTE) to filter and temporarily store successfully checked-out orders, ensuring only successful transactions are considered.
with successful_orders as (
  select o.order_id, o.customer_id
  from alt_school.orders o
  where o.status = 'success' -- filtering for successful orders
)

-- selecting the product_id and product_name along with the count of their appearances in successfully checked-out orders.
select
  p.id as product_id, -- retrieving product_id
  p.name as product_name, -- retrieving product_name
  count(*) as num_times_in_successful_orders -- counting occurrences of each product in successfully completed orders
from alt_school.events e
inner join successful_orders s on e.customer_id = s.customer_id -- matching customers with successful checkouts
inner join alt_school.orders o on s.order_id = o.order_id
inner join alt_school.line_items l on o.order_id = l.order_id
inner join alt_school.products p on l.item_id = p.id
where e.event_data->>'event_type' = 'add_to_cart' -- filtering for 'add_to_cart' events leading to successful checkouts
group by p.id, p.name -- grouping by product id and name
order by num_times_in_successful_orders desc -- ordering by the count of successful orders for each product
limit 1; -- limiting the result to the most frequently ordered item


-- 2. identifying the top 5 spenders without considering currency and without using the line_item table:

-- creating a CTE to filter and temporarily store successful order amounts, ensuring only completed orders are considered.
with order_amounts as (
  select o.customer_id, sum(p.price) as order_amount
  from alt_school.orders o
  inner join alt_school.events e on o.customer_id = e.customer_id
  inner join alt_school.products p on cast(e.event_data->>'item_id' as bigint) = p.id
  where o.status = 'success' -- filtering for successful orders
  group by o.customer_id
)

-- selecting customer_id, location, and total amount spent based on filtered successful orders.
select
  c.customer_id,
  c.location,
  sum(oa.order_amount) as total_spend
from alt_school.customers c
inner join order_amounts oa on c.customer_id = oa.customer_id
group by c.customer_id, c.location
order by total_spend desc
limit 5;


-- answers to question part 2b

-- 1. determining the most common location (country) where successful checkouts occurred:

-- creating a CTE to filter and temporarily store locations of successful checkouts, ensuring only successful transactions are considered.
with successful_locations as (
select
  c.location as location,
  count(*) as checkout_count
  from alt_school.events e
  inner join alt_school.customers c on e.customer_id = c.customer_id
  where e.event_data ->> 'event_type' = 'checkout' and e.event_data ->> 'status' = 'success'
  group by c.location
)

-- selecting the location with the maximum successful checkout events.
select
  sl.location,
  sl.checkout_count
from successful_locations sl
where sl.checkout_count = (select max(checkout_count) from successful_locations);


-- 2. identifying customers who abandoned their carts and the number of events (excluding visits) that occurred before abandonment:

-- creating a CTE to filter and temporarily store customers who abandoned their carts, ensuring only those with successful checkouts are considered.
with abandoned_carts as (
  select
    customer_id,
    cast(event_data ->> 'timestamp' as timestamp) as abandonment_timestamp
  from alt_school.events
  where not exists (
    select 1
    from alt_school.events e2
    where e2.customer_id = alt_school.events.customer_id
    and e2.event_timestamp > alt_school.events.event_timestamp
    and e2.event_data->>'event_type' = 'checkout'
  )
)

-- selecting customer_id and counting the number of events before abandonment.
select
  ac.customer_id,
  count(*) as num_events
from abandoned_carts ac
inner join alt_school.events e on ac.customer_id = e.customer_id
where e.event_data->>'event_type' <> 'visit'
  and e.event_timestamp < ac.abandonment_timestamp
group by ac.customer_id
order by num_events desc;


-- 3. calculating the average number of visits per customer, considering only customers who completed a checkout:

-- creating a CTE to temporarily store the total number of visits made by each customer.
with all_visits as (  
select e.customer_id,
  count(*) as num_of_visits
  from alt_school.events e
  where e.event_data ->> 'event_type' = 'visit'
  group by e.customer_id
)

-- selecting the average number of visits per customer who completed a checkout.
select
  round(avg(a.num_of_visits), 2) as average_visits
from all_visits a
inner join alt_school.events e on e.customer_id = a.customer_id
where e.event_data ->> 'status' = 'success';
