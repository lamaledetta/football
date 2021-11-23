begin;

create extension if not exists unaccent;

create temporary table r (
       rk	 serial,
       team 	 text,
       team_id   integer,
       year	 integer,
       str	 numeric(5,3),
       ofs	 numeric(5,3),
       dfs	 numeric(5,3),
       sos	 numeric(5,3)
);

insert into r
(team,team_id,year,str,ofs,dfs,sos)
(
select
unaccent(t.team_name),
sf.team_id,
sf.year,
(sf.strength)::numeric(5,3) as str,
(offensive)::numeric(5,3) as ofs,
(defensive)::numeric(5,3) as dfs,
schedule_strength::numeric(5,3) as sos
from _schedule_factors sf
join _results_ t
  on (t.year::integer,t.team_id)=(sf.year,sf.team_id)
where sf.year in (:'year')
--and   t.competition_id=:'comp'
--where   t.stage_id=:'stage_id'
order by str desc);

select
rk,team,str,ofs,dfs,sos
from r
order by rk asc;

copy
(
select
rk,team,str,ofs,dfs,sos
from r
order by rk asc
) to '/tmp/current_ranking.csv' csv header;

commit;
