select
team,
avg(rank)::numeric(3,1) as rank,
avg(w)::numeric(3,1) as w,
avg(d)::numeric(3,1) as d,
avg(l)::numeric(3,1) as l,
avg(pts)::numeric(4,1) as pts,
current_date as gen_date
from _sims group by team order by pts desc limit 20;

copy (
select
team,
avg(rank)::numeric(3,1) as rank,
avg(w)::numeric(3,1) as w,
avg(d)::numeric(3,1) as d,
avg(l)::numeric(3,1) as l,
avg(pts)::numeric(4,1) as pts,
current_date as gen_date
from _sims group by team order by pts desc limit 20
) to '/tmp/sim_table.csv' csv header;

--copy sim_table from '/tmp/sim_table.csv' csv header;
