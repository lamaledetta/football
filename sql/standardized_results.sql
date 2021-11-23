begin;

create extension if not exists unaccent;

drop table if exists _results_;

create table _results_ (
	game_id		      integer,
	game_date	      date,
	year		      integer,
	team_name	      text,
	team_id		      integer,
	opponent_name	      text,
	opponent_id	      integer,
	opponent_div_id	      integer,
	location_name	      text,
	location_id	      integer,
	field		      text,
	team_score	      real,
	opponent_score	      real
);

insert into _results_
(
game_id,game_date,year,
team_name,team_id,
opponent_name,opponent_id,
location_name,location_id,
field,
team_score,opponent_score)
(
select
g.matchid,
g.starttime::date,
g.season::integer,
case field when 'home' then unaccent(g.teamname) else 'not_valid' end,
case field when 'home' then g.teamid else 0 end,
case field when 'home' then unaccent(g.opponentname) else 'not_valid' end,
case field when 'home' then g.opponentid else 0 end,
case field when 'home' then unaccent(g.teamname) else 'not_valid' end as location_name,
case field when 'home' then g.teamid else 0 end as location_id,
'offense_home' as field,
sum(expg) as team_score,
(select sum(expg) from italyseriea.event t where t.matchid=g.matchid and t.teamname=g.opponentname) as opponent_score
from italyseriea.event g
where
    g.season=:'year'
and g.starttime::date < current_date
and g.expg!=0
group by g.matchid,g.starttime,g.season,g.field,g.teamname,g.teamid,g.opponentname,g.opponentid

union all

select
g.matchid,
g.starttime::date,
g.season::integer,
case field when 'home' then unaccent(g.teamname) else 'not_valid' end,
case field when 'home' then g.teamid else 0 end,
case field when 'home' then unaccent(g.opponentname) else 'not_valid' end,
case field when 'home' then g.opponentid else 0 end,
case field when 'home' then unaccent(g.teamname) else 'not_valid' end as location_name,
case field when 'home' then g.teamid else 0 end as location_id,
'defense_home' as field,
(select sum(expg) from italyseriea.event t where t.matchid=g.matchid and t.teamname=g.opponentname) as team_score,
sum(expg) as opponent_score
from italyseriea.event g
where
    g.season=:'year'
and g.starttime::date < current_date
and g.expg!=0
group by g.matchid,g.starttime,g.season,g.field,g.teamname,g.teamid,g.opponentname,g.opponentid

);

delete from _results_ where team_id=0 or opponent_id=0;

commit;
