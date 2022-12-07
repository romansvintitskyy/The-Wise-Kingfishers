-- Drop already existing tables to avoid errors
DROP TABLE IF EXISTS allegation_by_city_side;
DROP TABLE IF EXISTS north_side_area_codes;
DROP TABLE IF EXISTS south_side_area_codes;
DROP TABLE IF EXISTS annual_reports_north;
DROP TABLE IF EXISTS annual_reports_south;
DROP TABLE IF EXISTS median_incomes_north_areas;
DROP TABLE IF EXISTS median_incomes_south_areas;

--- Splitting the data into North and South sides
-- north

CREATE TEMP TABLE allegation_by_city_side AS (SELECT * FROM data_allegation);
ALTER TABLE allegation_by_city_side ADD COLUMN city_side text;
WITH north_side_areas AS
    (SELECT id FROM data_area WHERE area_type='community'
                                AND name IN
                                    ('O''Hare', 'Edison Park', 'Norwood Park', 'Jefferson Park', 'Forest Glen', 'North Park', 'Albany Park',
                                    'West Ridge', 'Lincoln Square', 'Rogers Park', 'Edgewater', 'Uptown', 'Dunning',
                                    'Montclare', 'Portage Park', 'Belmont Cragin', 'Irving Park', 'Hermosa', 'Avondale', 'Logan Square',
                                    'North Center', 'Lake View', 'Lincoln Park')),
    north_side_crids AS
        (SELECT crid FROM data_allegation a JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                     WHERE area_id IN (SELECT * FROM north_side_areas) )
UPDATE allegation_by_city_side SET city_side='north' WHERE crid IN (SELECT * FROM north_side_crids);

-- south Side
WITH south_side_areas AS
    (SELECT id FROM data_area WHERE area_type='community'
                                AND name
                                        IN ('Bridge Port', 'Amor Square', 'Fuller Park', 'Douglas', 'Grand Blvd',
                                           'Kenwood', 'Washington Park', 'Hyde Park', 'Woodlawn', 'Greater Grand Crossing',
                                           'south Shore', 'south Chicago', 'East Side', 'Avalon Park', 'Chatham', 'Burnside',
                                           'Calumet Heights', 'Roseland', 'Pullman', 'south Deering', 'East Side',
                                           'Hegewisch','Riverdale', 'West Pullman', 'Roseland', 'Pullman', 'Ashburn',
                                           'Auburn Gresham', 'Washington Heights', 'Beverly', 'Morgan Park', 'Mount Greenwood')),
    south_side_crids AS
        (SELECT crid FROM data_allegation a
            JOIN data_allegation_areas daa on a.crid = daa.allegation_id
                     WHERE area_id IN (SELECT * FROM south_side_areas) )
UPDATE allegation_by_city_side SET city_side='south' WHERE crid IN (SELECT * FROM south_side_crids);


-- helper tables --
create temp table north_side_area_codes as (
    select da.name, daa.area_id, abcs.crid from data_area da
        inner join data_allegation_areas daa on da.id = daa.area_id
        inner join allegation_by_city_side abcs on abcs.crid = daa.allegation_id
             where abcs.city_side='north'
             and da.area_type='community'
);
create temp table south_side_area_codes as (
    select da.name, daa.area_id, abcs.crid from data_area da
        inner join data_allegation_areas daa on da.id = daa.area_id
        inner join allegation_by_city_side abcs on abcs.crid = daa.allegation_id
             where abcs.city_side='south'
             and da.area_type='community'
);


-- ////// -----
-- 1. How many complaint reports are filed per capita on the north and south sides annually? --
-- north side population = 1039581.0
create temp table annual_reports_north as(
select * from (select extract(year from incident_date) as years, count(*) as reports, count(*)/1039581.0 as reports_per_capita_perc
from allegation_by_city_side
where incident_date is not null
and city_side='north'
group by years) as annual_reports_north where annual_reports_north.years>=2000);

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

--///---
-- 2. What is the racial distribution of each side of Chicago?
-- What is this distribution for complainants in the database? Put these side-by-side.
-- Use this query to find racial + complainant distribution for north
with racial_distribution as
    (select race, sum(count) as population
     from data_racepopulation
     where data_racepopulation.area_id in
           (select distinct nsac.area_id from north_side_area_codes nsac)
     group by race),
    complainant_distribution as
        (select temp_table.race, count(temp_table.race) complainants
         from
             (select dc.allegation_id, dc.race
              from data_complainant dc
              where dc.allegation_id in
                    (select distinct nsac.crid from north_side_area_codes nsac)
                and dc.race != ''
              group by (allegation_id, race)) as temp_table
         group by temp_table.race)
    select * from racial_distribution full outer join complainant_distribution on racial_distribution.race=complainant_distribution.race;

-- Use this query to find racial + complainant distribution for south
with racial_distribution as
    (select race, sum(count) as population
     from data_racepopulation
     where data_racepopulation.area_id in
           (select distinct nsac.area_id from south_side_area_codes nsac)
     group by race),
    complainant_distribution as
        (select temp_table.race, count(temp_table.race) complainants
         from
             (select dc.allegation_id, dc.race
              from data_complainant dc
              where dc.allegation_id in
                    (select distinct ssac.crid from south_side_area_codes ssac)
                and dc.race != ''
              group by (allegation_id, race)) as temp_table
         group by temp_table.race)
    select * from racial_distribution full outer join complainant_distribution on racial_distribution.race=complainant_distribution.race;

-- ///////---
--3. What is the distribution of complaint categories in the north and south sides?
-- north, count by subcategories
with officer_allegationcategory as
(select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
from data_officerallegation doa
    inner join north_side_area_codes nsac on nsac.crid=doa.allegation_id
group by doa.allegation_id, doa.allegation_category_id)
    select dac.category_code, dac.category, dac.allegation_name, count(dac.category_code)
    from data_allegationcategory dac
        inner join officer_allegationcategory oa
            on dac.id=oa.allegation_category_id
group by dac.category_code, dac.category, dac.allegation_name
order by count(*) desc;

-- Use this query to answer Q3 for north, count by category
with officer_allegationcategory as
(select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
from data_officerallegation doa
    inner join north_side_area_codes nsac on nsac.crid=doa.allegation_id
group by doa.allegation_id, doa.allegation_category_id)
    select dac.category, count(dac.category)
    from data_allegationcategory dac
        inner join officer_allegationcategory oa
            on dac.id=oa.allegation_category_id
group by dac.category
order by count(*) desc;

-- Use this query to answer Q3 for south, count by subcategories
with officer_allegationcategory as
(select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
from data_officerallegation doa
    inner join south_side_area_codes ssac on ssac.crid=doa.allegation_id
group by doa.allegation_id, doa.allegation_category_id)
    select dac.category_code, dac.category, dac.allegation_name, count(dac.category_code)
    from data_allegationcategory dac
        inner join officer_allegationcategory oa
            on dac.id=oa.allegation_category_id
group by dac.category_code, dac.category, dac.allegation_name;

-- Use this query to answer Q3 for south, count by category
with officer_allegationcategory as
(select doa.allegation_id, doa.allegation_category_id, count(doa.allegation_id)
from data_officerallegation doa
    inner join south_side_area_codes ssac on ssac.crid=doa.allegation_id
group by doa.allegation_id, doa.allegation_category_id)
    select dac.category, count(dac.category)
    from data_allegationcategory dac
        inner join officer_allegationcategory oa
            on dac.id=oa.allegation_category_id
group by dac.category
order by count(*) desc;

-- 4. What is the median income of the north and south sides?
-- north
-- median incomes
create temp table median_incomes_north_areas as
(select distinct nsac.name, CAST(translate(da.median_income, '$,', '') as integer) as median_income
from data_area da inner join north_side_area_codes nsac on da.id = nsac.area_id);

-- south
-- median incomes
create temp table median_incomes_south_areas as
(select distinct ssac.name, CAST(translate(da.median_income, '$,', '') as integer) as median_income
from data_area da inner join south_side_area_codes ssac on da.id = ssac.area_id);

-- Use this query to find  median incomes in the north and south sides
select
    (select percentile_cont(0.5) within group(order by median_incomes_north_areas.median_income)
        from median_incomes_north_areas) as north_median_income,
-- 51713
    (select percentile_cont(0.5) within group(order by median_incomes_south_areas.median_income)
        from median_incomes_south_areas) as south_median_income;
-- 37084

SELECT extract(year from incident_date) as years from data_allegation;