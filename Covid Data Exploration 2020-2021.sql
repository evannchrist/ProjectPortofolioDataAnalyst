-- Please note that the data used is from 2021, taken from https://ourworldindata.org/covid-deaths. There may be some differences from the most recent data available on that site.

-- For the same data used in this project, it will be uploaded to this project's repository. Under the names "CovidDeaths" & "CovidVaccinations"

-- check database connection
Select *
from ProjectPorto.dbo.CovidDeaths


Select *
from ProjectPorto.dbo.CovidVaccination

-- Key questions 

---------------------------------------------------------------

-- 1. True Pandemic Burden (Beyond Case Counts)
-- Which countries had the highest death rate per population? >> Identifies fragile health systems
-- How did the fatality rate change over time? >> Reveals improvement/collapse of care
-- Which regions were hit hardest in the first wave? >> Guides future early-response focus

SELECT 
    location, 
    MAX(total_deaths / population * 100) AS death_rate_percent
FROM ProjectPorto..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY death_rate_percent DESC;

---------------------------------------------------------------

-- 2. Health System Resilience
-- Deaths per case reflect hospital overload & care quality.
-- High Case Fatality Rate (CFR) despite similar case levels = weak ICU capacity, staffing, oxygen access.

SELECT
    location,
    AVG(
        TRY_CAST(total_deaths AS float)
        / NULLIF(TRY_CAST(total_cases AS float), 0)
        * 100
    ) AS avg_case_fatality_rate
FROM ProjectPorto..CovidDeaths
WHERE continent IS NOT NULL
  AND TRY_CAST(total_cases AS float) > 1000
GROUP BY location
ORDER BY avg_case_fatality_rate DESC;

---------------------------------------------------------------

-- 3. Speed of Spread vs Speed of Vaccination
-- how fast vaccination must move to beat viral growth.
-- If infection curve grows faster than vaccination ? country will lose control.

SELECT
    d.location,
    d.date,

    -- Vaccination progress (% of population)
    SUM(TRY_CAST(v.new_vaccinations AS float))
        OVER (PARTITION BY d.location ORDER BY d.date)
        / NULLIF(TRY_CAST(d.population AS float), 0) * 100
        AS vaccination_progress,

    -- Infection progress (% of population)
    SUM(TRY_CAST(d.new_cases AS float))
        OVER (PARTITION BY d.location ORDER BY d.date)
        / NULLIF(TRY_CAST(d.population AS float), 0) * 100
        AS infection_progress

FROM ProjectPorto..CovidDeaths d
JOIN ProjectPorto..CovidVaccination v
    ON d.location = v.location
   AND d.date = v.date
WHERE d.continent IS NOT NULL
--and d.location like '%Indo%' --"search bar" for location;

---------------------------------------------------------------

-- 4. Vaccine Impact on Mortality
-- Did vaccines reduce deaths in real life?
-- After vaccination rate passes certain thresholds, deaths should flatten or drop. If not ? variant spread or delayed vaccine protection.

WITH rolling AS (
    SELECT 
        d.location,
        d.date,

        -- Vaccination rate (% of population)
        SUM(TRY_CAST(v.new_vaccinations AS float))
            OVER (PARTITION BY d.location ORDER BY d.date)
            / NULLIF(TRY_CAST(d.population AS float), 0) * 100
            AS vax_rate,

        -- 14-day rolling deaths
        SUM(TRY_CAST(d.new_deaths AS float))
            OVER (
                PARTITION BY d.location 
                ORDER BY d.date 
                ROWS BETWEEN 14 PRECEDING AND CURRENT ROW
            ) AS deaths_14d

    FROM ProjectPorto..CovidDeaths d
    JOIN ProjectPorto..CovidVaccination v
      ON d.location = v.location
     AND d.date = v.date
    WHERE d.continent IS NOT NULL
    --and d.location like '%state%' --"search bar" for location;
)

SELECT *
FROM rolling
WHERE vax_rate >= 10
ORDER BY location, date;

---------------------------------------------------------------

-- 5. Inequality in Vaccine Distribution
-- Pandemics end only when all regions improve.
-- Large gaps = geopolitical failure that will repeat in the next pandemic.
-- Please note that the data on vaccinations represents the total doses given, meaning it's possible for the percentage to exceed 100%.

SELECT
    d.continent,
    MAX(
        TRY_CAST(v.people_vaccinated AS float)
        / NULLIF(TRY_CAST(d.population AS float), 0) * 100
    ) AS max_people_vaccinated_pct
FROM ProjectPorto..CovidVaccination v
JOIN ProjectPorto..CovidDeaths d
  ON v.location = d.location
 AND v.date = d.date
WHERE d.continent IS NOT NULL
GROUP BY d.continent

ORDER BY max_people_vaccinated_pct DESC;
