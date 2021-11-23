begin;

drop table if exists _sims;

create table _sims (
	team		      text,
	n		      integer,
	rank		      integer,
	w		      integer,
	d		      integer,
	l		      integer,
	gf		      integer,
	ga		      integer,
	gd		      integer,
	pts		      integer,
	primary key (team,n)
);

copy _sims FROM '/tmp/sims.csv' WITH (FORMAT CSV, DELIMITER ',', HEADER);

commit;
