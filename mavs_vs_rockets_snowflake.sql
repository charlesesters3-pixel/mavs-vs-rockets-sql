/* =====================================================================
   MAVERICKS vs. ROCKETS — Which Franchise Has Been Better?  (Snowflake SQL)
   Source: Basketball-Reference franchise pages; Rockets 2019-20 to 2025-26
           records confirmed via season summaries (SRS not captured -> NULL).
   season_end = year the season ended (2026 = the 2025-26 season).
   Rockets date back to 1967-68 (San Diego through 1970-71);
   Mavericks began in 1980-81. The fair comparison window is 1981-2026.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 0. SETUP
-- ---------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS nba_wh
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
CREATE DATABASE IF NOT EXISTS texas_nba;
CREATE SCHEMA   IF NOT EXISTS texas_nba.analysis;
USE WAREHOUSE nba_wh;
USE SCHEMA texas_nba.analysis;

-- ---------------------------------------------------------------------
-- 1. LOOKUP: how far a team went in the playoffs
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE playoff_rounds (round_code INT, result VARCHAR, playoff_points INT);
INSERT INTO playoff_rounds VALUES
(0,'Missed playoffs',   0),
(2,'Lost 1st round',    1),
(3,'Lost conf. semis',  2),
(4,'Lost conf. finals', 3),
(5,'Lost NBA Finals',   4),
(6,'Won NBA title',     6);   -- title weighted extra; tweak to test your story

-- ---------------------------------------------------------------------
-- 2. FRANCHISE SEASONS
--    srs = Simple Rating System (point differential adjusted for schedule;
--          0 = average team, +5 = very good, -5 = very bad)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE franchise_seasons (
    team VARCHAR, season_end INT, wins INT, losses INT, srs FLOAT, round_code INT
);
INSERT INTO franchise_seasons VALUES
('Dallas Mavericks',2026,26,56,-5.33,0),
('Dallas Mavericks',2025,39,43,-0.74,0),
('Dallas Mavericks',2024,50,32,2.30,5),
('Dallas Mavericks',2023,38,44,-0.14,0),
('Dallas Mavericks',2022,52,30,3.12,4),
('Dallas Mavericks',2021,42,30,2.26,2),
('Dallas Mavericks',2020,43,32,4.87,2),
('Dallas Mavericks',2019,33,49,-0.87,0),
('Dallas Mavericks',2018,24,58,-2.70,0),
('Dallas Mavericks',2017,33,49,-2.53,0),
('Dallas Mavericks',2016,42,40,-0.02,2),
('Dallas Mavericks',2015,50,32,3.36,2),
('Dallas Mavericks',2014,49,33,2.91,2),
('Dallas Mavericks',2013,41,41,-0.24,0),
('Dallas Mavericks',2012,36,30,1.78,2),
('Dallas Mavericks',2011,57,25,4.41,6),
('Dallas Mavericks',2010,55,27,2.66,2),
('Dallas Mavericks',2009,50,32,1.68,3),
('Dallas Mavericks',2008,51,31,4.70,2),
('Dallas Mavericks',2007,67,15,7.28,2),
('Dallas Mavericks',2006,60,22,5.96,5),
('Dallas Mavericks',2005,58,24,5.86,3),
('Dallas Mavericks',2004,52,30,4.86,2),
('Dallas Mavericks',2003,60,22,7.90,4),
('Dallas Mavericks',2002,57,25,4.41,3),
('Dallas Mavericks',2001,53,29,4.61,3),
('Dallas Mavericks',2000,40,42,-0.29,0),
('Dallas Mavericks',1999,19,31,-2.50,0),
('Dallas Mavericks',1998,20,62,-6.33,0),
('Dallas Mavericks',1997,24,58,-6.47,0),
('Dallas Mavericks',1996,26,56,-4.71,0),
('Dallas Mavericks',1995,36,46,-2.39,0),
('Dallas Mavericks',1994,13,69,-8.19,0),
('Dallas Mavericks',1993,11,71,-14.68,0),
('Dallas Mavericks',1992,22,60,-7.47,0),
('Dallas Mavericks',1991,28,54,-4.27,0),
('Dallas Mavericks',1990,47,35,0.42,2),
('Dallas Mavericks',1989,38,44,-1.79,0),
('Dallas Mavericks',1988,53,29,3.59,4),
('Dallas Mavericks',1987,55,27,5.54,2),
('Dallas Mavericks',1986,44,38,0.70,3),
('Dallas Mavericks',1985,44,38,1.80,2),
('Dallas Mavericks',1984,43,39,0.15,3),
('Dallas Mavericks',1983,38,44,-0.70,0),
('Dallas Mavericks',1982,28,54,-4.48,0),
('Dallas Mavericks',1981,15,67,-8.33,0),
('Houston Rockets',2026,52,30,NULL,2),
('Houston Rockets',2025,52,30,NULL,2),
('Houston Rockets',2024,41,41,NULL,0),
('Houston Rockets',2023,22,60,NULL,0),
('Houston Rockets',2022,20,62,NULL,0),
('Houston Rockets',2021,17,55,NULL,0),
('Houston Rockets',2020,44,28,NULL,3),
('Houston Rockets',2019,53,29,4.96,3),
('Houston Rockets',2018,65,17,8.21,4),
('Houston Rockets',2017,55,27,5.84,3),
('Houston Rockets',2016,41,41,0.34,2),
('Houston Rockets',2015,56,26,3.82,4),
('Houston Rockets',2014,54,28,5.06,2),
('Houston Rockets',2013,45,37,3.69,2),
('Houston Rockets',2012,34,32,0.57,0),
('Houston Rockets',2011,43,39,2.37,0),
('Houston Rockets',2010,42,40,-0.02,0),
('Houston Rockets',2009,53,29,3.73,3),
('Houston Rockets',2008,55,27,4.83,2),
('Houston Rockets',2007,52,30,5.04,2),
('Houston Rockets',2006,34,48,-1.30,0),
('Houston Rockets',2005,51,31,4.27,2),
('Houston Rockets',2004,45,37,2.28,2),
('Houston Rockets',2003,43,39,1.89,0),
('Houston Rockets',2002,28,54,-4.31,0),
('Houston Rockets',2001,45,37,2.71,0),
('Houston Rockets',2000,34,48,-0.57,0),
('Houston Rockets',1999,31,19,1.39,2),
('Houston Rockets',1998,41,41,-1.23,2),
('Houston Rockets',1997,57,25,3.85,4),
('Houston Rockets',1996,48,34,1.63,3),
('Houston Rockets',1995,47,35,2.32,6),
('Houston Rockets',1994,58,24,4.19,6),
('Houston Rockets',1993,55,27,3.57,3),
('Houston Rockets',1992,42,40,-1.94,0),
('Houston Rockets',1991,52,30,3.27,2),
('Houston Rockets',1990,41,41,1.71,2),
('Houston Rockets',1989,45,37,0.22,2),
('Houston Rockets',1988,46,36,0.82,2),
('Houston Rockets',1987,42,40,0.60,3),
('Houston Rockets',1986,51,31,2.10,5),
('Houston Rockets',1985,48,34,1.38,2),
('Houston Rockets',1984,29,53,-3.12,0),
('Houston Rockets',1983,14,68,-11.12,0),
('Houston Rockets',1982,46,36,-0.39,2),
('Houston Rockets',1981,40,42,-0.20,5),
('Houston Rockets',1980,41,41,0.27,3),
('Houston Rockets',1979,47,35,0.92,2),
('Houston Rockets',1978,28,54,-3.83,0),
('Houston Rockets',1977,49,33,1.44,4),
('Houston Rockets',1976,40,42,-0.71,0),
('Houston Rockets',1975,41,41,0.84,3),
('Houston Rockets',1974,32,50,-0.34,0),
('Houston Rockets',1973,33,49,-1.81,0),
('Houston Rockets',1972,34,48,-1.22,0),
('Houston Rockets',1971,40,42,0.21,0),
('Houston Rockets',1970,27,55,-2.95,0),
('Houston Rockets',1969,37,45,-0.30,2),
('Houston Rockets',1968,15,67,-7.94,0);

-- ---------------------------------------------------------------------
-- 3. PLAYOFF MEETINGS BETWEEN THE TWO
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE head_to_head_playoffs (season_end INT, round VARCHAR, winner VARCHAR, series VARCHAR);
INSERT INTO head_to_head_playoffs VALUES
(1988,'West 1st round','Dallas Mavericks','3-1'),
(2005,'West 1st round','Dallas Mavericks','4-3'),
(2015,'West 1st round','Houston Rockets','4-1');

-- ---------------------------------------------------------------------
-- 4. ENRICHED VIEW
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW season_view AS
SELECT f.*,
       (f.season_end - 1) || '-' || RIGHT(f.season_end::VARCHAR, 2)  AS season_label,
       ROUND(f.wins / (f.wins + f.losses), 3)                         AS win_pct,
       FLOOR((f.season_end - 1) / 10) * 10                            AS decade,
       f.round_code > 0                                               AS made_playoffs,
       p.result, p.playoff_points
FROM franchise_seasons f
JOIN playoff_rounds p ON p.round_code = f.round_code;

-- ---------------------------------------------------------------------
-- 5. ANALYSIS QUERIES
-- ---------------------------------------------------------------------

-- Q1: The scoreboard — shared era only (1980-81 onward)
SELECT team,
       COUNT(*)                                         AS seasons,
       SUM(wins) || '-' || SUM(losses)                  AS record,
       ROUND(SUM(wins) / SUM(wins + losses), 3)         AS win_pct,
       COUNT_IF(made_playoffs)                          AS playoff_trips,
       COUNT_IF(round_code >= 4)                        AS conf_finals,
       COUNT_IF(round_code >= 5)                        AS finals_trips,
       COUNT_IF(round_code = 6)                         AS titles,
       COUNT_IF(wins >= 50)                             AS fifty_win_seasons,
       COUNT_IF(win_pct < .300)                         AS disaster_seasons
FROM season_view
WHERE season_end >= 1981
GROUP BY team;

-- Q2: Decade by decade — who owned each era?
SELECT decade || 's'                                    AS decade,
       team,
       SUM(wins) || '-' || SUM(losses)                  AS record,
       ROUND(SUM(wins) / SUM(wins + losses), 3)         AS win_pct,
       COUNT_IF(made_playoffs)                          AS playoff_trips,
       SUM(playoff_points)                              AS playoff_points,
       RANK() OVER (PARTITION BY decade ORDER BY SUM(wins) / SUM(wins + losses) DESC) AS decade_rank
FROM season_view
WHERE season_end >= 1981
GROUP BY decade, team
ORDER BY decade, decade_rank;

-- Q3: Season-by-season head-to-head: which team had the better record each year?
WITH paired AS (
    SELECT d.season_label,
           d.win_pct AS dal_pct, h.win_pct AS hou_pct,
           CASE WHEN d.win_pct > h.win_pct THEN 'Dallas Mavericks'
                WHEN h.win_pct > d.win_pct THEN 'Houston Rockets'
                ELSE 'Tie' END AS better_team
    FROM season_view d
    JOIN season_view h ON h.season_end = d.season_end AND h.team = 'Houston Rockets'
    WHERE d.team = 'Dallas Mavericks'
)
SELECT better_team, COUNT(*) AS seasons_on_top
FROM paired GROUP BY better_team;

-- Q4: Longest playoff streaks (gaps-and-islands pattern)
WITH flagged AS (
    SELECT team, season_end, made_playoffs,
           season_end - ROW_NUMBER() OVER (PARTITION BY team ORDER BY season_end) AS grp
    FROM season_view
    WHERE made_playoffs
)
SELECT team, MIN(season_end) AS streak_start, MAX(season_end) AS streak_end, COUNT(*) AS seasons
FROM flagged
GROUP BY team, grp
QUALIFY ROW_NUMBER() OVER (PARTITION BY team ORDER BY COUNT(*) DESC) = 1;

-- Q5: Peak teams — each franchise's 5 best seasons by SRS
SELECT team, season_label, wins, losses, srs, result
FROM season_view
WHERE srs IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY team ORDER BY srs DESC) <= 5
ORDER BY team, srs DESC;

-- Q6: Rolling 5-year win% (smooths out single seasons — great line chart)
SELECT team,
       season_end::VARCHAR AS season,
       ROUND(SUM(wins) OVER (PARTITION BY team ORDER BY season_end ROWS BETWEEN 4 PRECEDING AND CURRENT ROW)
           / SUM(wins + losses) OVER (PARTITION BY team ORDER BY season_end ROWS BETWEEN 4 PRECEDING AND CURRENT ROW), 3)
           AS rolling_5yr_win_pct
FROM season_view
WHERE season_end >= 1981
ORDER BY season_end, team;

-- Q7: Consistency — how much each team swings year to year
SELECT team,
       ROUND(AVG(win_pct), 3)    AS avg_win_pct,
       ROUND(STDDEV(win_pct), 3) AS volatility
FROM season_view
WHERE season_end >= 1981
GROUP BY team;

-- Q8: When they met in the playoffs
SELECT winner, COUNT(*) AS series_won, LISTAGG(season_end || ' (' || series || ')', ', ') AS details
FROM head_to_head_playoffs
GROUP BY winner;

-- Q9: Franchise all-time (Rockets include pre-Mavs years since 1967-68)
SELECT team, MIN(season_end) - 1 || '-' || RIGHT(MIN(season_end)::VARCHAR, 2) AS first_season,
       SUM(wins) || '-' || SUM(losses) AS all_time_record,
       ROUND(SUM(wins) / SUM(wins + losses), 3) AS win_pct,
       COUNT_IF(made_playoffs) AS playoff_trips, COUNT_IF(round_code = 6) AS titles
FROM season_view
GROUP BY team;
