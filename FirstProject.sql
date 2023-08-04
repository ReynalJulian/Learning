SELECT *
FROM CovidCasesAndDeaths

SELECT *
FROM CovidDemographics

SELECT *
FROM CovidTestsAndVaccinations

-- Find total cases by country (SELECT, Aggregate Function)
SELECT location, MAX(CAST(total_cases AS int)) country_total
FROM CovidCasesAndDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY location

-- Find total deaths by region (Subquery)
SELECT location, MAX(CAST(total_deaths AS int)) continent_total
FROM CovidCasesAndDeaths
WHERE continent IS NULL 
AND 
location IN (SELECT DISTINCT continent FROM CovidCasesAndDeaths WHERE continent IS NOT NULL)
GROUP BY location
ORDER BY continent_total DESC

-- Find worldwide daily cases, deaths, and vaccination (Join)
SELECT cnd.date, SUM(cnd.new_cases) daily_cases, SUM(cnd.new_deaths) daily_deaths, SUM(CAST(tnv.new_vaccinations AS bigint)) daily_vaccinations
FROM CovidCasesAndDeaths cnd
INNER JOIN CovidTestsAndVaccinations tnv
ON cnd.date = tnv.date 
AND cnd.location = tnv.location
WHERE cnd.date >= '2021-01-01'
AND cnd.date <= '2021-12-31'
AND cnd.continent IS NOT NULL
GROUP by cnd.date
ORDER by cnd.date

-- Daily growth rate of new cases in Indonesia (Multiple Casts, LAG)
SELECT location, date, CAST(total_cases AS int) AS totalcases, new_cases, 
	CAST(new_cases/
	LAG(
		CAST(total_cases AS float),1) OVER (ORDER BY date) 
	AS decimal(5,3)) as daily_growth
FROM CovidCasesAndDeaths
WHERE location = 'Indonesia'
ORDER by date

-- Find total cases per capita by country (Temp Table, Join)
DROP TABLE IF EXISTS #latest_total_cases
CREATE TABLE #latest_total_cases
(
location nvarchar(255),
total_cases_max nvarchar(255)
)
INSERT INTO #latest_total_cases
SELECT location, MAX(CAST(total_cases AS int)) 
FROM CovidCasesAndDeaths
GROUP BY location

SELECT DISTINCT cnd.location, total_cases_max/population as cases_per_capita
FROM CovidCasesAndDeaths cnd
JOIN #latest_total_cases ltc
ON cnd.location = ltc.location
WHERE continent IS NOT NULL
ORDER BY cnd.location

SELECT *
FROM #latest_total_cases

-- Correlation of deaths per capita to gdp and HDI (Multiple Joins)
SELECT cnd.continent, cnd.location, CAST(CAST(total_deaths AS float)/cnd.population AS decimal(8,8)) AS death_per_capita, dem.gdp_per_capita, dem.human_development_index
FROM CovidCasesAndDeaths cnd
INNER JOIN
(SELECT continent, location, MAX(date) as max_date
FROM CovidCasesAndDeaths
GROUP BY continent, location) find_date
ON cnd.date = find_date.max_date
AND cnd.continent = find_date.continent
AND cnd.location = find_date.location
INNER JOIN CovidDemographics dem
ON dem.date = find_date.max_date
AND dem.continent = find_date.continent
AND dem.location = find_date.location
WHERE cnd.continent IS NOT NULL
ORDER BY cnd.continent, cnd.location

-- Daily rolling percentage of vaccination rate by country
WITH CTE AS
(
SELECT cnd.continent, cnd.location, cnd.date, cnd.population, tnv.new_vaccinations, SUM(CONVERT(float, tnv.new_vaccinations)) OVER(PARTITION BY cnd.location ORDER BY tnv.date) AS vaccination_accumulation
FROM CovidCasesAndDeaths cnd
INNER JOIN CovidTestsAndVaccinations tnv
ON cnd.date = tnv.date
AND cnd.continent = tnv.continent
AND cnd.location = tnv.location
WHERE cnd.continent IS NOT NULL
)
SELECT *, vaccination_accumulation/population AS vaccination_rate
FROM CTE
ORDER BY continent, location
--Clean data duplicates (CTE, Partition By)
WITH CTE AS
(
SELECT *, ROW_NUMBER() OVER(PARTITION BY continent,location,date ORDER BY continent,location,date) AS dup
FROM CovidCasesAndDeaths
)
DELETE FROM CTE
WHERE dup <> 1


-- Find latest death rate by country (Join with subquery)
SELECT	cnd.location,
		CAST(cnd.total_cases AS int) AS totalcases, 
		CAST(cnd.total_deaths AS int) AS totaldeaths, 
		CAST(
				CAST(cnd.total_deaths AS float)/CAST(cnd.total_cases AS float)
				AS decimal(5,3))
		AS death_rate
FROM CovidCasesAndDeaths cnd
INNER JOIN (SELECT	continent, location, MAX(date) as Max_Date
					FROM CovidCasesAndDeaths
					GROUP BY continent, location) AS Max_Date_Table
ON cnd.location = Max_Date_Table.location
AND cnd.continent = Max_Date_Table.continent
AND cnd.date = Max_Date
WHERE cnd.continent IS NOT NULL

