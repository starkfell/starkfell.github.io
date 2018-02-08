
# --- Stream Analytic Queries integrated with Power BI and Azure Web Apps.


# ----- Query 1 -----
WITH Availabilities AS

(
	SELECT
	GetArrayElement(Availability,0)as avails 
	FROM [input-logs-availability]
)

SELECT
avails.testRunId,
avails.testTimestamp,
avails.testName,
avails.runLocation
FROM Availabilities


# ----- Query 2 - Returns all records but doesn't take into account nested Arrays -----
WITH Availabilities AS

(
	SELECT
	GetArrayElement(Availability,0)as avails 
	FROM [input-logs-availability]
)

SELECT
avails.*

FROM Availabilities


# ----- Query 3: Requests Query & Timestamp ----- #

WITH Requests AS

(
	SELECT
	GetArrayElement(Request,0) as reqs,
    context.location.clientip,
    context.location.continent,
    context.location.country,
    context.location.city,
    context.data.eventtime
	FROM [input-requests]
    TIMESTAMP BY context.data.eventtime
)

SELECT
reqs.id,
reqs.name,
reqs.count,
reqs.responseCode,
reqs.success,
reqs.urlData.base,
clientip,
continent,
country,
city,
eventtime
FROM Requests



# ----- Query 4: Requests Context Test Request ----- #

/*
SELECT 
context.location.clientip,
context.location.continent,
context.location.country,
context.location.city
FROM [input-requests]
*/


# This is the configuration that is required for the Stream Analytics Configuration. This pattern can be found in the Storage Account where Continuous Export is sending data to.
Instrumentation Key
b2971937-3c24-426e-9ca2-c8a8531dcfdc

lumawebappnxey_b29719373c24426e9ca2c8a8531dcfdc/Requests/{date}/{time}

lumawebappnxey_b29719373c24426e9ca2c8a8531dcfdc


# MAKE SURE THAT THE INPUT CONFIGURATION FOR DATE/TIME IS USING "-" AND NOT "/" FOR PATTERN MATCHING!!!





# ------------------------------------------------------------------------------------------------- #

WITH PerformanceCounters AS

(
	SELECT
	GetArrayElement(performanceCounter,0) as counters,
    context.location.clientip,
    context.location.continent,
    context.location.country,
    context.location.city,
    context.data.eventtime
	FROM [input-performance-counters]
    TIMESTAMP BY context.data.eventtime
)

SELECT
counters.percentage_processor_time,
counters.requests_per_sec,
counters.number_of_exceps_thrown_per_sec,
counters.request_execution_time,
counters.process_private_bytes,
counters.io_data_bytes_per_sec,
counters.requests_in_application_queue,
clientip,
continent,
country,
city,
eventtime
FROM PerformanceCounters


/* Select * From [input-performance-counters] */





########################################################

WITH PerformanceCounters AS

(
	SELECT
	GetArrayElement(performanceCounter,0) as counters,
    context.location.clientip,
    context.location.continent,
    context.location.country,
    context.location.city,
    context.data.eventtime
	FROM [input-performance-counters]
    TIMESTAMP BY context.data.eventtime
)

SELECT
counters.percentage_processor_time,
clientip,
continent,
country,
city,
eventtime
INTO ProcessorTime
FROM PerformanceCounters
WHERE counters.percentage_processor_time IS NOT NULL

SELECT
counters.requests_per_sec,
clientip,
continent,
country,
city,
eventtime
INTO RequestsPerSec
FROM PerformanceCounters
WHERE counters.requests_per_sec IS NOT NULL

SELECT
counters.request_execution_time,
clientip,
continent,
country,
city,
eventtime
INTO RequestExecutionTime
FROM PerformanceCounters
WHERE counters.request_execution_time IS NOT NULL




############# Page Views ########################

WITH PageViews AS

(
	SELECT
	GetArrayElement([view],0) as views,
    context.location.clientip,
    context.location.continent,
    context.location.country,
    context.location.city,
    context.data.eventtime
	FROM [input-page-views]
    TIMESTAMP BY context.data.eventtime
)

SELECT
PageViews.views.name,
PageViews.views.count,
(PageViews.views.durationMetric.value) as durationMetric,
(PageViews.views.durationMetric.stddev) as standardDeviation,
clientip,
continent,
country,
city,
eventtime
FROM PageViews


################# ASP.NET Home Page View Duration ##########################

WITH PageViews AS

(
	SELECT
	GetArrayElement([view],0) as views,
    context.location.clientip,
    context.location.continent,
    context.location.country,
    context.location.city,
    context.data.eventtime
	FROM [input-page-views]
    TIMESTAMP BY context.data.eventtime
)

SELECT
PageViews.views.name,
PageViews.views.count,
CAST(PageViews.views.durationMetric.value as float)/1000000 as durationMetric,
(PageViews.views.durationMetric.stddev) as standardDeviation,
clientip,
continent,
country,
city,
eventtime
FROM PageViews
WHERE PageViews.views.name LIKE 'Home Page%'




