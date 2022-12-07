
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
CREATE TEMP TABLE temp_crids AS
    (SELECT crid FROM data_allegation a
        JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                 WHERE area_id IN (SELECT * FROM area_ids) );
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
select * from absolute_allegations_by_pd;
select * from popul_by_pd;
drop table if exists per_capita_allegations_by_pd;
create temp table per_capita_allegations_by_pd as (
    select aabpd.name, aabpd.area_id, aabpd.count/pbpd.population::float pc_val
    from absolute_allegations_by_pd aabpd
    join popul_by_pd pbpd on aabpd.area_id = pbpd.area_id
);
select * from per_capita_allegations_by_pd;


-- -- ////// -----
-- -- 1. How many complaint reports are filed per capita on the north and south sides annually? --
-- -- north side population = 1039581.0
-- DROP TABLE IF EXISTS reports_by_pd;
-- create temp table reports_by_pd as
--     ( select *
--       from
--           (
--             select area_id, count(*) as reports, count(*)/population::float as reports_per_capita_perc
--             from temp_crids, popul_by_pd)
-- --             where incident_date is not null
-- --             group by area_id, population)
--               as annual_reports_north);
-- --       group);
-- --       where annual_reports_north.years>=2000);
-- select * from reports_by_pd;
--
-- -- south side population = 4453195.0
-- DROP TABLE IF EXISTS annual_reports_south;
-- create temp table annual_reports_south as
--     (select *
--      from
--          (select extract(year from incident_date) as years, count(*) as reports, count(*)/population::float as reports_per_capita_per
--           from allegation_by_city_side,south_side_population
--           where incident_date is not null and city_side='south' group by years, population)
--              as annual_reports_north
--      where annual_reports_north.years>=2000);
--
-- -- Use this query to see the side-by-side results for question 1
-- select ars.years as Year, ars.reports_per_capita_per as South_per_capita_perc, arn.reports_per_capita_perc as north_per_capita_perc
-- from annual_reports_south ars
--     join annual_reports_north arn on ars.years=arn.years;
--
-- --///---
-- -- 2. What is the racial distribution of each side of Chicago?
-- -- What is this distribution for complainants in the database? Put these side-by-side.
-- -- Use this query to find racial + complainant distribution for north
-- with racial_distribution as
--         (select race, sum(count) as population
--          from data_racepopulation
--          where data_racepopulation.area_id in
--                (select * FROM north_area_ids) group by race),
--     complainant_distribution as
--         (select temp_table.race, count(temp_table.race) complainants
--          from (select dc.allegation_id, dc.race
--                from data_complainant dc
--                where dc.allegation_id in
--                      (select distinct nsac.crid from north_side_area_codes nsac) and dc.race != ''
--                group by (allegation_id, race)) as temp_table
--          group by temp_table.race)
--
-- select * from racial_distribution
--     full outer join complainant_distribution on racial_distribution.race=complainant_distribution.race;
--
-- --
-- select race, sum(count) as population
-- from data_racepopulation
-- where data_racepopulation.area_id in
--       (select distinct nsac.area_id
--        from south_side_area_codes nsac)
-- group by race;
--
-- select temp_table.race, count(temp_table.race) complainants
-- from (select dc.allegation_id, dc.race
--       from data_complainant dc
--       where dc.allegation_id in (select distinct ssac.crid from south_side_area_codes ssac) and dc.race != ''
--       group by (allegation_id, race)) as temp_table
-- group by temp_table.race;
--
-- -- Use this query to find racial + complainant distribution for south
-- with racial_distribution as
--         (select race, sum(count) as population
--          from data_racepopulation
--          where data_racepopulation.area_id in
--                (select distinct nsac.area_id
--                 from south_side_area_codes nsac)
--          group by race),
--     complainant_distribution as
--         (select temp_table.race, count(temp_table.race) complainants
--          from (select dc.allegation_id, dc.race
--                from data_complainant dc
--                where dc.allegation_id in
--                      (select distinct ssac.crid
--                       from south_side_area_codes ssac) and dc.race != ''
--                group by (allegation_id, race)) as temp_table
--          group by temp_table.race)
--
-- select racial_distribution.race, coalesce(racial_distribution.population, 0) population, complainant_distribution.*
-- from racial_distribution
--     full outer join complainant_distribution on racial_distribution.race=complainant_distribution.race;
--
-- -- ///////---
-- --3. What is the distribution of complaint categories in the north and south sides?
-- -- north, count by subcategories
-- with officer_allegationcategory as
--     (select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
--      from data_officerallegation doa
--          inner join north_side_area_codes nsac on nsac.crid=doa.allegation_id
--      group by doa.allegation_id, doa.allegation_category_id)
--
-- select dac.category_code, dac.category, dac.allegation_name, count(dac.category_code)
-- from data_allegationcategory dac
--     inner join officer_allegationcategory oa on dac.id=oa.allegation_category_id
-- group by dac.category_code, dac.category, dac.allegation_name
-- order by count(*) desc;
--
-- -- Use this query to answer Q3 for north, count by category
-- with officer_allegationcategory as
--     (select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
--      from data_officerallegation doa
--          inner join north_side_area_codes nsac on nsac.crid=doa.allegation_id
--      group by doa.allegation_id, doa.allegation_category_id)
--
-- select dac.category, count(dac.category)
-- from data_allegationcategory dac
--     inner join officer_allegationcategory oa on dac.id=oa.allegation_category_id
-- group by dac.category order by count(*) desc;
--
-- -- Use this query to answer Q3 for south, count by subcategories --
-- with officer_allegationcategory as
--     (select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
--      from data_officerallegation doa
--          inner join south_side_area_codes ssac on ssac.crid=doa.allegation_id
--      group by doa.allegation_id, doa.allegation_category_id)
--
-- select dac.category_code, dac.category, dac.allegation_name, count(dac.category_code)
-- from data_allegationcategory dac
--     inner join officer_allegationcategory oa
--         on dac.id=oa.allegation_category_id
-- group by dac.category_code, dac.category, dac.allegation_name;
--
-- -- Use this query to answer Q3 for south, count by category
-- with officer_allegationcategory as
--     (select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
--      from data_officerallegation doa
--          inner join south_side_area_codes ssac on ssac.crid=doa.allegation_id
--      group by doa.allegation_id, doa.allegation_category_id)
--
-- select dac.category, count(dac.category)
-- from data_allegationcategory dac
--     inner join officer_allegationcategory oa on dac.id=oa.allegation_category_id
-- group by dac.category order by count(*) desc;
--
-- -- 4. What is the median income of the north and south sides? -- north -- median incomes
-- --
-- create temp table median_incomes_north_areas as
--     (select distinct nsac.name, CAST(translate(da.median_income, '$,', '') as integer) as median_income
--      from data_area da
--          inner join north_side_area_codes nsac on da.id = nsac.area_id);
--
-- -- south -- median incomes
-- create temp table median_incomes_south_areas as
--     (select distinct ssac.name, CAST(translate(da.median_income, '$,', '') as integer) as median_income
--      from data_area da inner join south_side_area_codes ssac on da.id = ssac.area_id);
--
-- -- Use this query to find median incomes in the north and south sides
-- --
-- select (select percentile_cont(0.5) within group(order by median_incomes_north_areas.median_income)
--         from median_incomes_north_areas) as north_median_income,
--
--     (select percentile_cont(0.5) within group(order by median_incomes_south_areas.median_income)
--      from median_incomes_south_areas) as south_median_income; -- 37084
--
--
-- select * from north_side_area_codes;


-- drop table if exists southPopulationTemp;
-- create temp table southPopulationTemp as (
--     select race, round(sum(count)/490706.0, 4) as pop_perc
--          from data_racepopulation
--          where data_racepopulation.area_id in
--                (select distinct nsac.area_id
--                 from south_side_area_codes nsac)
--          group by race
-- );
--
-- select * from southPopulationTemp order by  pop_perc desc;
--
--
-- drop table if exists northPopulationTemp;
-- create temp table northPopulationTemp as (
--     select race, round(sum(count)/1050655.0, 4) as pop_perc
--
--          from data_racepopulation
--          where data_racepopulation.area_id in
--                (select distinct nsac.area_id
--                 from north_side_area_codes nsac)
--          group by race
-- );
--
-- select * from northPopulationTemp order by pop_perc desc ;
--
-- drop table if exists policeRacDistr;
-- create temp table policeRacDistr as (
--     select race, round(count(race)/35545.0, 4) as pop_perc
--     from data_officer
--     group by race
-- );
--
-- select sum(pop_perc) from policeRacDistr;
--
-- select * from policeRacDistr
-- order by pop_perc desc;


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
WITH officer_counts AS
        (SELECT race, last_unit_id unit_id, COUNT(*) cnt
         FROM data_officer
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
FROM officers_mapped o JOIN community_percent c ON c.area_id = o.area_id AND c.race = o.race;




SELECT district_name, COUNT(*)
FROM data_officer o
    JOIN data_policeunit dp on o.last_unit_id = dp.id
    JOIN district_polygons d ON dp.id = d.unit_id
WHERE resignation_date IS NULL
GROUP BY district_name
ORDER BY district_name;

-- SELECT *
-- FROM data_officer o
--     JOIN data_policeunit dp on o.last_unit_id = dp.id
--     JOIN district_polygons d ON dp.id = d.unit_id
-- WHERE resignation_date IS NULL;

-- Racial Distribution of civilians per PD
SELECT r.area_id, race, "count" civilian_cnt, "count"::float / district_total pct_community
          FROM data_racepopulation r
              JOIN (SELECT area_id, sum("count") district_total
                    FROM data_racepopulation
                    GROUP BY area_id) denominator ON denominator.area_id = r.area_id
          WHERE r.area_id IN (SELECT area_id FROM district_polygons);

