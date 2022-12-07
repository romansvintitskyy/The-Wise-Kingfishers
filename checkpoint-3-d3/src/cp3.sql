-- Q1: we reused code for Q3 Checkpoint 1 (checkpoint-1.sql)

-- Q2

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
    (SELECT crid FROM data_allegation a
        JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                 WHERE area_id IN (SELECT id FROM area_ids) );
select * from temp_crids;

-- Mapping crids, PD name, and PD area ids
drop table if exists area_codes;
create temp table area_codes as
    ( select da.name, daa.area_id, abcs.crid
      from data_area da
          inner join data_allegation_areas daa on da.id = daa.area_id
          inner join temp_crids abcs on abcs.crid = daa.allegation_id
      where da.area_type='police-districts' );
select * from area_codes;

-- Total Allegation counts by each PD (grouped by name)
drop table if exists absolute_allegations_by_pd;
create temp table absolute_allegations_by_pd as (
    select ac.name, ac.area_id, count(*) -- I excluded ac.area_id,
    from area_codes ac
    inner join data_allegation da on ac.crid=da.crid
    group by ac.name, ac.area_id);
select * from absolute_allegations_by_pd;

-- Allegation Counts per capita
drop table if exists per_capita_allegations_by_pd;
create temp table per_capita_allegations_by_pd as (
    select aabpd.name, aabpd.area_id, aabpd.count/pbpd.population::float pc_val
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

-- Racial counts (percentages) of officers and civilians per PD
WITH officer_counts AS
        (SELECT race, last_unit_id unit_id, COUNT(*) cnt
         FROM data_officer
         GROUP BY race, last_unit_id),
    officer_percentages AS
        ( SELECT o.unit_id, o.race, o.cnt, unit_total, o.cnt::float / unit_total officer_pct
          FROM officer_counts o
              JOIN (SELECT unit_id, sum(cnt) unit_total
                    FROM officer_counts
                    GROUP BY unit_id) denominator ON o.unit_id = denominator.unit_id ),
    community_percent AS
        ( SELECT r.area_id, race, "count"::float / district_total pct_community
          FROM data_racepopulation r
              JOIN (SELECT area_id, sum("count") district_total
                    FROM data_racepopulation
                    GROUP BY area_id) denominator ON denominator.area_id = r.area_id
          WHERE r.area_id IN (SELECT area_id FROM district_polygons) ),
    officers_mapped AS
        ( SELECT d.area_id, o.unit_id, race, dp.unit_name, dp.description, officer_pct, polygon
          FROM officer_percentages o
              JOIN data_policeunit dp ON o.unit_id = dp.id
              JOIN district_polygons d on dp.id = d.unit_id )

SELECT o.area_id, o.unit_name, o.race, officer_pct, c.pct_community community_pct, polygon
FROM officers_mapped o JOIN community_percent c ON c.area_id = o.area_id AND c.race = o.race;



-- Racial counts (absolute values) of officers and civilians per PD
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
        ( SELECT d.area_id, o.unit_id, race, dp.unit_name, dp.description, officer_cnt, officer_pct, district_name, polygon
          FROM officer_percentages o
              JOIN data_policeunit dp ON o.unit_id = dp.id
              JOIN district_polygons d on dp.id = d.unit_id )

SELECT district_name, o.race, officer_cnt, civilian_cnt, polygon
FROM officers_mapped o
    JOIN community_percent c ON c.area_id = o.area_id AND c.race = o.race;


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

select unit_name, race, civilian_cnt as cnt, round(100.0*community_pct::numeric,2) as pct from civ_police_racial_distr_by_pd;
select unit_name, race, officer_cnt as cnt, round(100.0*officer_pct::numeric,2) as pct from civ_police_racial_distr_by_pd;

select * from civ_police_racial_distr_by_pd;



