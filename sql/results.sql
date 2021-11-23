create temporary table ttt
(
    team    text,
    rank    integer,
    n       integer,
    primary key (team,rank)
);

insert into ttt
(team,rank,n) (
select team,rank,count(*) as n
from _sims
group by team,rank
);

select team,
sum(case when rank=1 then round(100.0*n/10000,2) else 0 end) as champ,
sum(case when rank<=4 then round(100.0*n/10000,2) else 0 end) as cl,
sum(case when rank<=6 and rank>=5 then round(100.0*n/10000,2) else 0 end) as el,
sum(case when rank>=18 then round(100.0*n/10000,2) else 0 end) as rel
from ttt
group by team
order by champ desc,cl desc,el desc, rel asc;

copy (
select team,rank,count(*) as n
from _sims
group by team,rank
order by rank asc, n desc
) to '/tmp/results.csv' csv header;

