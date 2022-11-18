
-- Retrieving Police districts area ids
DROP TABLE if exists area_ids;
CREATE TEMP TABLE area_ids AS
    ( SELECT id, name FROM data_area
      WHERE area_type='police-districts');
SELECT * FROM area_ids;

-- Determining civilian population of each PD
DROP TABLE IF EXISTS popul_by_pd;
CREATE TEMP TABLE popul_by_pd AS
    ( SELECT area_id, SUM("count") population FROM data_racepopulation
      WHERE area_id IN (SELECT id FROM area_ids)
      group by area_id);
select * from popul_by_pd;

-- Retrieving CRIDs for the PD areas ids
drop table if exists temp_crids;
CREATE TEMP TABLE temp_crids AS
    (SELECT crid, extract(year from incident_date) as years FROM data_allegation a
        JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                 WHERE area_id IN (SELECT id FROM area_ids)
                 group by crid, years
                 );
select * from temp_crids;

-- Mapping crids, PD name, and PD area ids
drop table if exists area_codes;
create temp table area_codes as
    ( select da.name, daa.area_id, abcs.crid, abcs.years
      from data_area da
          inner join data_allegation_areas daa on da.id = daa.area_id
          inner join temp_crids abcs on abcs.crid = daa.allegation_id
      where da.area_type='police-districts'
      and abcs.years >= 2000);
select * from area_codes;

-- Total Allegation counts by each PD (grouped by name)
drop table if exists absolute_allegations_by_pd;
create temp table absolute_allegations_by_pd as (
    select ac.years, ac.name, ac.area_id, count(*) -- I excluded ac.area_id,
    from area_codes ac
    inner join data_allegation da on ac.crid=da.crid
    group by ac.years,ac.name, ac.area_id);
select * from absolute_allegations_by_pd;

-- Allegation Counts per capita
drop table if exists per_capita_allegations_by_pd;
create temp table per_capita_allegations_by_pd as (
    select aabpd.years,aabpd.name, aabpd.area_id, aabpd.count/pbpd.population::float allegations_pc_val
    from absolute_allegations_by_pd aabpd
    join popul_by_pd pbpd on aabpd.area_id = pbpd.area_id
);
select * from per_capita_allegations_by_pd;


-- District polygons
DROP TABLE IF EXISTS district_polygons;
CREATE TEMP TABLE district_polygons AS
    ( SELECT a.id area_id, dp.id unit_id, UPPER(a.name) district_name, ST_AsGeoJSON(a.polygon, 4)::json polygon
      FROM data_policeunit dp
          JOIN data_area a ON left(name, -2)::INT = unit_name::INT WHERE area_type = 'police-districts');


----------- Racial distribution of officers and civilians per PD
-- Racial counts (absolute values and percentages) of officers and civilians per PD
DROP TABLE IF EXISTS civ_police_racial_distr_by_pd;
CREATE TEMP TABLE civ_police_racial_distr_by_pd as (
    WITH officer_counts AS
        (SELECT race, last_unit_id unit_id, COUNT(*) cnt
         FROM data_officer
         WHERE resignation_date IS NULL
         GROUP BY race, last_unit_id),
    officer_percentages AS
        ( SELECT o.unit_id, o.race, o.cnt officer_cnt, unit_total, o.cnt::float / unit_total officer_pct
          FROM officer_counts o
              JOIN (SELECT unit_id, sum(cnt) unit_total
                    FROM officer_counts
                    GROUP BY unit_id) denominator ON o.unit_id = denominator.unit_id ),
    community_percent AS
        ( SELECT r.area_id, race, "count" civilian_cnt, "count"::float / district_total pct_community
          FROM data_racepopulation r
              JOIN (SELECT area_id, sum("count") district_total
                    FROM data_racepopulation
                    GROUP BY area_id) denominator ON denominator.area_id = r.area_id
          WHERE r.area_id IN (SELECT area_id FROM district_polygons) ),
    officers_mapped AS
        ( SELECT d.area_id, o.unit_id, race, dp.unit_name, dp.description, officer_cnt, officer_pct, polygon
          FROM officer_percentages o
              JOIN data_policeunit dp ON o.unit_id = dp.id
              JOIN district_polygons d on dp.id = d.unit_id )

SELECT o.area_id, o.unit_name, o.race, officer_cnt, officer_pct, civilian_cnt, c.pct_community community_pct, polygon
FROM officers_mapped o JOIN community_percent c ON c.area_id = o.area_id AND c.race = o.race
);

-- UPDATING THE UNIT NAME SO IT MATCHES OUR FORMAT -- this is the one I use
UPDATE civ_police_racial_distr_by_pd
SET unit_name =
( CASE
    WHEN (unit_name = '011') THEN '11TH'
    WHEN (unit_name = '022') THEN '22ND'
    WHEN (unit_name = '005') THEN '5TH'
    WHEN (unit_name = '020') THEN '20TH'
    WHEN (unit_name = '002') THEN '2ND'
    WHEN (unit_name = '010') THEN '10TH'
    WHEN (unit_name = '007') THEN '7TH'
    WHEN (unit_name = '001') THEN '1ST'
    WHEN (unit_name = '024') THEN '24TH'
    WHEN (unit_name = '009') THEN '9TH'
    WHEN (unit_name = '016') THEN '16TH'
    WHEN (unit_name = '014') THEN '14TH'
    WHEN (unit_name = '003') THEN '3RD'
    WHEN (unit_name = '018') THEN '18TH'
    WHEN (unit_name = '012') THEN '12TH'
    WHEN (unit_name = '015') THEN '15TH'
    WHEN (unit_name = '017') THEN '17TH'
    WHEN (unit_name = '004') THEN '4TH'
    WHEN (unit_name = '008') THEN '8TH'
    WHEN (unit_name = '019') THEN '19TH'
    WHEN (unit_name = '025') THEN '25TH'
    WHEN (unit_name = '006') THEN '6TH'
END )
WHERE unit_name in (select unit_name from  civ_police_racial_distr_by_pd);


drop table if exists officer_counts;
create temp table officer_counts AS
        (SELECT race, last_unit_id unit_id, COUNT(*) cnt
         FROM data_officer
         WHERE resignation_date IS NULL
         GROUP BY race, last_unit_id);

drop table if exists officer_percentages;
create temp table
    officer_percentages AS
        ( SELECT o.unit_id, o.race, o.cnt officer_cnt, unit_total, o.cnt::float / unit_total officer_pct
          FROM officer_counts o
              JOIN (SELECT unit_id, sum(cnt) unit_total
                    FROM officer_counts
                    GROUP BY unit_id) denominator ON o.unit_id = denominator.unit_id );

drop table if exists officers_mapped;
    create temp table officers_mapped AS
        ( SELECT d.area_id, o.unit_id, race, dp.unit_name, dp.description, officer_cnt, officer_pct, polygon
          FROM officer_percentages o
              JOIN data_policeunit dp ON o.unit_id = dp.id
              JOIN district_polygons d on dp.id = d.unit_id
            );
select * from officers_mapped;

drop table if exists officer_unit_count;
create temp table officer_unit_count as (
    select unit_name, sum(officer_cnt) total_num_officers
    from officers_mapped
    group by unit_name
);
select * from officer_unit_count;

drop table if exists officer_count_per_pd;
create temp table officer_count_per_pd as (
    select area_id, total_num_officers
    from officers_mapped
    join officer_unit_count ouc on officers_mapped.unit_name = ouc.unit_name
);
select * from officer_count_per_pd;


drop table if exists in_progress;
create temp table in_progress as (
    select  pcabp.years, main.area_id, main.unit_name, main.race, main.officer_cnt, main.officer_pct, main.civilian_cnt,
       main.community_pct, pcabp.allegations_pc_val, ocpp.total_num_officers
    from civ_police_racial_distr_by_pd main
    join per_capita_allegations_by_pd pcabp on main.area_id = pcabp.area_id
    join officer_count_per_pd ocpp on main.area_id = ocpp.area_id
);


-- feed this into jupyter
select distinct * from in_progress
order by years, unit_name asc;

select count(*) from data_officerhistory
where effective_date <= '2017-12-31'
and end_date >= '2017-01-01';
-- and resignation_date not between '2000-01-01' and '2000-12-31'
-- and active = 'Yes';

-- drop table if exists data_officer_temp;
-- create temp table data_officer_temp as (
--     SELECT * from data_officer
-- );
-- ALTER TABLE data_officer_temp
-- add column

with temp_counts as (
    select last_unit_id, count(*) num from data_officer
    where appointed_date <= '2018-12-31'
    and (resignation_date >= '2018-01-01'
       or resignation_date is null)
    group by last_unit_id
),
    temp_temp as (
    select * from temp_counts tc
             join data_policeunit dpu on tc.last_unit_id::integer= dpu.unit_name::integer
)
select (select sum(num) from temp_temp
where description like 'District%'
and unit_name in ('018', '019', '020', '024', '016', '017', '014', '025')) north,
    (select sum(num) from temp_temp
where description like 'District%'
and unit_name in ('002', '009', '008', '007', '003', '004', '006', '022', '005')) south;











drop table if exists allegation_by_city_side;
CREATE TEMP TABLE allegation_by_city_side AS (SELECT * FROM data_allegation);
ALTER TABLE allegation_by_city_side ADD COLUMN city_side text;
WITH north_side_areas AS
    (SELECT id FROM data_area WHERE area_type='police-districts'
                                AND name IN
                                    ('18th', '19th', '20th', '24th', '16th', '17th', '14th', '25th')),
    north_side_crids AS
        (SELECT crid FROM data_allegation a JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                     WHERE area_id IN (SELECT * FROM north_side_areas) )
UPDATE allegation_by_city_side SET city_side='north' WHERE crid IN (SELECT * FROM north_side_crids);

-- south Side
WITH south_side_areas AS
    (SELECT id FROM data_area WHERE area_type='police-districts'
                                AND name
                                        IN ('2nd', '9th', '8th', '7th', '3rd', '4th', '6th', '22nd', '5th')),
    south_side_crids AS
        (SELECT crid FROM data_allegation a
            JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                     WHERE area_id IN (SELECT * FROM south_side_areas) )
UPDATE allegation_by_city_side SET city_side='south' WHERE crid IN (SELECT * FROM south_side_crids);


-- helper tables --
drop table if exists north_side_area_codes;
create temp table north_side_area_codes as (
    select da.name, daa.area_id, abcs.crid from data_area da
        inner join data_allegation_areas daa on da.id = daa.area_id
        inner join allegation_by_city_side abcs on abcs.crid = daa.allegation_id
             where abcs.city_side='north'
             and da.area_type='police-districts'
);

drop table if exists south_side_area_codes;
create temp table south_side_area_codes as (
    select da.name, daa.area_id, abcs.crid from data_area da
        inner join data_allegation_areas daa on da.id = daa.area_id
        inner join allegation_by_city_side abcs on abcs.crid = daa.allegation_id
             where abcs.city_side='south'
             and da.area_type='police-districts'
);


-- ////// -----
-- 1. How many complaint reports are filed per capita on the north and south sides annually? --
-- north side population = 1039581.0
drop table if exists annual_reports_north;
create temp table annual_reports_north as(
select * from (select extract(year from incident_date) as years, count(*) as reports, count(*)/1039581.0 as reports_per_capita_perc
from allegation_by_city_side
where incident_date is not null
and city_side='north'
group by years) as annual_reports_north where annual_reports_north.years>=2000);

drop table if exists annual_reports_south;
-- south side population = 4453195.0
create temp table annual_reports_south as
(select * from (select extract(year from incident_date) as years, count(*) as reports, count(*)/4453195.0 as reports_per_capita_per
from allegation_by_city_side
where incident_date is not null
and city_side='south'
group by years) as annual_reports_north where annual_reports_north.years>=2000);

-- Use this query to see the side-by-side results for question 1
select ars.years as Year, ars.reports_per_capita_per as South_per_capita_perc, arn.reports_per_capita_perc as north_per_capita_perc
from annual_reports_south ars
    join annual_reports_north arn on ars.years=arn.years;

CREATE temp TABLE police_counts_per_city_side (
	year char,
	north int,
	south int
);
INSERT INTO police_counts_per_city_side (year, north, south)
VALUES
('2000',2537, 3090),
('2001',2558, 3096),
('2002',2554, 3110),
('2003',2535, 3098),
('2004',2535, 3098),
('2005', 2524, 3149),
('2006', 2543, 3246),
('2007', 2504, 3250),
('2008', 2444, 3188),
('2009', 2378, 3138),
('2010', 2318, 3124),
('2011', 2211, 3012),
('2012', 2164, 3055),
('2013', 2130, 3125),
('2014', 2135, 3181),
('2015', 2152, 3236),
('2016', 2155, 3304),
('2017', 2063, 3178),
('2018', 1974, 3059);

select pcpcs.year, South_per_capita_perc south_cr_per_capita, north_per_capita_perc north_cr_per_capita, north north_police_count, south south_police_count  from police_counts_per_city_side pcpcs
join (
    select ars.years as Year, ars.reports_per_capita_per as South_per_capita_perc, arn.reports_per_capita_perc as north_per_capita_perc
    from annual_reports_south ars
    join annual_reports_north arn on ars.years=arn.years
) temp on temp.Year = pcpcs.year;

