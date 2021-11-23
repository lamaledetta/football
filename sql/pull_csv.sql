begin;

-- Remaining games

copy (
select
g.start_date,
g.stage_id,
g.stage_name,
t.team_name as home_team_name,
o.team_name as away_team_name,

skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'win') as home_win,
skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'draw') as draw,
skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'lose') as away_win

from fixtures g
join standings t
  on (t.team_id,t.season,t.stage_id)=(g.home_team_id,g.season,g.stage_id)
join _schedule_factors sft
  on (sft.team_id,sft.year)=(g.home_team_id,g.season::integer)
join standings o
  on (o.team_id,o.season,o.stage_id)=(g.away_team_id,g.season,g.stage_id)
join _schedule_factors sfo
  on (sfo.team_id,sfo.year)=(g.away_team_id,g.season::integer)
join _factors tf on
  tf.level='offense_home'
join _factors of on
  of.level='defense_home'
where
--    not(g.date='LIVE')
--and g.league_key = 'barclays+premier+league'
    g.stage_id=:'stage_id'
--    g.competition_id=:'comp'
--and g.season=:'year'
and g.start_date::date >= current_date
and g.home_score is null
and g.away_score is null
--and g.team_id=g.home_team_id
order by g.start_date::date asc
limit 10
) to '/tmp/predictions.csv' csv header;


create temporary table _expg_t (
    team_id integer,
    xfor    real,
    xaga    real
);

insert into _expg_t (
    team_id,
    xfor,
    xaga
) (
select
    t.team_id,
    sum(case t.team_id when g.home_team_id then g.home_expg
    when                    g.away_team_id then g.away_expg
    else 0 end)/count(g.id),
    sum(case t.team_id when g.home_team_id then g.away_expg
    when                    g.away_team_id then g.home_expg
    else 0 end)/count(g.id)
    from standings t, match g
    where
    g.stage_id=:'stage_id'
--    g.competition_id=:'comp'
--and g.season=:'year'
and g.start_date::date < current_date
and g.home_score is not null
and g.away_score is not null
and (t.team_id=g.home_team_id or t.team_id=g.away_team_id)
and t.stage_id=g.stage_id
--and t.competition_id=g.competition_id
--and t.season=g.season
    group by t.team_id
);

select
g.start_date,
g.stage_id,
g.stage_name,
t.team_name as home_team_name,
o.team_name as away_team_name,

skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'win') as home_win,
skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'draw') as draw,
skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'lose') as away_win,
--round(((xgh.xfor+xgh.xaga+xga.xfor+xga.xaga)/2-2.5)::numeric,2) as avg_goals,
round((1/skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'win' ))::numeric,2) as uno,
round((1/skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'draw'))::numeric,2) as ics,
round((1/skellam(tf.exp_factor*sft.offensive,of.exp_factor*sfo.offensive,'lose'))::numeric,2) as due

from fixtures g
join standings t
  on (t.team_id,t.season,t.stage_id)=(g.home_team_id,g.season,g.stage_id)
join _schedule_factors sft
  on (sft.team_id,sft.year)=(g.home_team_id,g.season::integer)
join standings o
  on (o.team_id,o.season,o.stage_id)=(g.away_team_id,g.season,g.stage_id)
join _schedule_factors sfo
  on (sfo.team_id,sfo.year)=(g.away_team_id,g.season::integer)
join _factors tf on
  tf.level='offense_home'
join _factors of on
  of.level='defense_home'
join _expg_t xgh
  on xgh.team_id=g.home_team_id
join _expg_t xga
  on xga.team_id=g.away_team_id
where
--    not(g.date='LIVE')
--and g.league_key = 'barclays+premier+league'
    g.stage_id=:'stage_id'
--    g.competition_id=:'comp'
--and g.season=:'year'
and g.start_date::date >= current_date
and g.home_score is null
and g.away_score is null
--and g.team_id=g.home_team_id
order by g.start_date::date
limit 10
;
-- Table

--copy (
--select
--s.team_name as team,
--sum(
--case when s.team_id=g.home_team_id
--     and (g.home_score > g.away_score) then 1
--     when s.team_id=g.away_team_id
--     and (g.home_score < g.away_score) then 1
--else 0
--end) as w,
--sum(
--case when s.team_id=g.home_team_id
--     and (g.home_score=g.away_score) then 1
--     when s.team_id=g.away_team_id
--     and (g.home_score=g.away_score) then 1
--else 0
--end) as d,
--sum(
--case when s.team_id=g.home_team_id
--     and (g.home_score < g.away_score) then 1
--     when s.team_id=g.away_team_id
--     and (g.home_score > g.away_score) then 1
--else 0
--end) as l
--
--from match g, standings s
--where
----    not(g.date='LIVE')
----and g.league_key = 'barclays+premier+league'
--    g.competition_id=:'comp'
--and g.season=:'year'
--and s.competition_id=g.competition_id
--and s.season=g.season
--and g.match_date::date <= current_date
--and g.home_score is not null
--and g.away_score is not null
--group by s.team_name
--order by s.team_name asc
--
--) to '/tmp/table.csv' csv header;

commit;
