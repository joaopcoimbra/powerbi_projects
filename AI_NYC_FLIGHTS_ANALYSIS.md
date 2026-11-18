# NYC Flights — Data Analysis (2013)

## Overview

This analysis answers ten questions about flight operations, destinations, departure delays, weather conditions, airlines, and aircraft using the five supplied CSV datasets.

**Scope:** January 1–December 31, 2013; flights departing from **EWR, JFK, and LGA**.  
**Observed flights:** **277,977**; **365** observed calendar dates.  
**Recommended reporting tool:** Power BI, using a PBIP project for version control.

### Source files and join keys

| Dataset | Role | Main fields / join keys |
|---|---|---|
| `nyc_flights_fixed.csv` | Flight-level fact data | `year`, `month`, `day`, `origin`, `dest`, `carrier`, `tailnum`, `dep_delay`, `time_hour` |
| `nyc_airlines.csv` | Airline names | `carrier` |
| `nyc_planes.csv` | Aircraft attributes and seat capacity | `tailnum`, `manufacturer`, `model`, `seats` |
| `nyc_weather.csv` | Hourly weather by airport | `origin`, `time_hour`, `precip`, `humid`, `dewp`, `temp`, `wind_speed`, `visib`, `pressure` |
| `nyc_airports.csv` | Airport lookup details | `faa`, `name` |

**Important:** This report analyzes the provided *fixed* flight file, not the complete original NYC flights benchmark dataset. Results should not be generalized to records absent from this file.

## Executive summary

| # | Question | Result |
|---|---|---|
| 1 | Number of distinct destinations | **100** |
| 2 | Rounded average of distinct destinations per calendar day | **81** (unrounded: **81.08**) |
| 3 | Average distinct destinations by day of week | **Sunday leads: 83.00**; full table below |
| 4 | Month with the most flights | **August: 24,290 flights** |
| 5 | Month with the highest cumulative departure delay | **July: 535,995 minutes** (net sum) |
| 6 | Relationship between weather and departure delays | **Rainy periods: 30.29 min average delay** vs. **11.79 min** without precipitation; weak linear relationships for individual weather variables |
| 7 | Airline with the most flights | **United Air Lines (UA): 55,802 flights** |
| 8 | Airline with the highest average daily seats offered | **United Air Lines (UA): 27,014 seats/day**, rounded |
| 9 | Most common aircraft manufacturer (registered planes) | **BOEING: 1,630 aircraft** |
| 10 | Most common aircraft model (registered planes) | **737-7H4: 361 aircraft** |

## Detailed findings and calculation rules

### 1. How many distinct destinations are connected to the airports?

**Answer: 100 destinations.**

Count distinct non-null `dest` values across the full flight file, aggregating across EWR, JFK, and LGA. A destination served by more than one origin is counted once.

### 2. What is the rounded average number of distinct destinations per day?

**Answer: 81** (unrounded **81.0767**).

1. Count unique `dest` values for each `year-month-day` date, across all three origins.
2. Average those 365 daily counts.
3. Round the final result to the nearest whole destination.

Do **not** divide the 100 distinct annual destinations by 365; the metric is the *average of daily distinct counts*.

### 3. What is the average number of destinations by day of the week?

| Day | Average daily distinct destinations | Observed days |
|---|---:|---:|
| Monday | 81.79 | 52 |
| Tuesday | 80.40 | 53 |
| Wednesday | 80.48 | 52 |
| Thursday | 82.56 | 52 |
| Friday | 81.92 | 52 |
| Saturday | 77.40 | 52 |
| Sunday | **83.00** | 52 |

The aggregation is two-stage: first distinct destinations **per date**, then average across the dates belonging to each weekday. Sunday has the highest average; Saturday has the lowest.

### 4. Which month has the most flights?

**Answer: August (24,290 flights).**

| Month | Flights |
|---|---:|
| January | 21,989 |
| February | 20,142 |
| March | 23,650 |
| April | 23,424 |
| May | 23,959 |
| June | 23,258 |
| July | 24,174 |
| **August** | **24,290** |
| September | 22,954 |
| October | 24,236 |
| November | 22,836 |
| December | 23,065 |

This counts rows in `nyc_flights_fixed.csv` as flight records.

### 5. Which month has the greatest accumulated departure delay?

**Answer: July, with 535,995 minutes of *net* departure delay.**

| Month | Net departure delay (minutes) |
|---|---:|
| January | 235,034 |
| February | 222,863 |
| March | 333,070 |
| April | 328,093 |
| May | 314,223 |
| June | 490,911 |
| **July** | **535,995** |
| August | 315,761 |
| September | 159,860 |
| October | 164,626 |
| November | 132,845 |
| December | 392,629 |

**Metric definition:** `SUM(dep_delay)` includes negative values for early departures, which offset late departures. If *accumulated late minutes* means summing **only positive** delays, use `SUM(MAX(dep_delay, 0))` at the flight level; **July still leads with 583,738 positive delay minutes**. State explicitly which definition is in use.

### 6. How do weather conditions relate to departure delays?

Join each flight to the hourly weather observation on **both** `origin` and `time_hour`. The two-column key is required because multiple airports have weather measurements for the same hour. A row-level many-to-one match is valid for these files.

**Precipitation comparison:**

| Weather condition | Flights | Average departure delay (minutes) |
|---|---:|---:|
| No precipitation (`precip = 0`) | 258,012 | 11.79 |
| With precipitation (`precip > 0`) | 18,676 | **30.29** |

The rainy group has an average departure delay approximately **18.50 minutes higher** than the dry group, an observed association rather than proof of causality.

**Pearson correlation with `dep_delay` (paired non-missing observations):**

| Weather measure | Pearson r | Direction |
|---|---:|---|
| Relative humidity (`humid`) | +0.1128 | Weak positive |
| Dew point (`dewp`) | +0.0988 | Weak positive |
| Precipitation (`precip`) | +0.0858 | Weak positive |
| Temperature (`temp`) | +0.0594 | Weak positive |
| Wind speed (`wind_speed`) | +0.0460 | Weak positive |
| Visibility (`visib`) | −0.0898 | Weak negative |
| Atmospheric pressure (`pressure`) | −0.1147 | Weak negative |

**Interpretation:** High humidity and precipitation tend to coincide with greater departure delays; lower visibility and lower atmospheric pressure also tend to coincide with greater delays. Individual linear correlations are **weak**, and other factors (airport congestion, route, seasonality, traffic, and scheduling) may contribute. No causal claim is justified by these statistics alone.

**Join coverage:** 276,688 of 277,977 flights (**99.54%**) matched weather records; **1,289** did not. Rain/dry comparisons exclude unmatched rows.

### 7. Rank airlines by number of flights

| Rank | Carrier | Airline | Flights |
|---:|---|---|---:|
| 1 | UA | United Air Lines Inc. | **55,802** |
| 2 | EV | ExpressJet Airlines Inc. | 54,173 |
| 3 | B6 | JetBlue Airways | 50,194 |
| 4 | DL | Delta Air Lines Inc. | 46,669 |
| 5 | US | US Airways Inc. | 19,837 |
| 6 | 9E | Endeavor Air Inc. | 17,416 |
| 7 | WN | Southwest Airlines Co. | 12,237 |
| 8 | AA | American Airlines Inc. | 10,090 |
| 9 | VX | Virgin America | 5,162 |
| 10 | FL | AirTran Airways Corporation | 3,073 |
| 11 | MQ | Envoy Air | 1,000 |
| 12 | AS | Alaska Airlines Inc. | 714 |
| 13 | F9 | Frontier Airlines Inc. | 635 |
| 14 | YV | Mesa Airlines Inc. | 601 |
| 15 | HA | Hawaiian Airlines Inc. | 342 |
| 16 | OO | SkyWest Airlines Inc. | 32 |

**Definition:** `COUNTROWS(flights)` grouped by `carrier` and enriched with `nyc_airlines.name`.

### 8. Rank airlines by daily seat availability

**Interpretation used:** *Average number of seat opportunities offered per calendar day*, based on each flown aircraft's nominal seating capacity—not unique fleet capacity, booked seats, or confirmed unsold seats.

For each flight, attach `nyc_planes.seats` using `tailnum`; sum seat capacity **for each flight occurrence**; divide the annual total for each airline by **365 observed days**. Thus the same 180-seat airplane flying three segments generates 540 offered seats.

| Rank | Carrier | Airline | Average seats per day (rounded) |
|---:|---|---|---:|
| 1 | UA | United Air Lines Inc. | **27,014** |
| 2 | DL | Delta Air Lines Inc. | 21,559 |
| 3 | B6 | JetBlue Airways | 17,856 |
| 4 | US | US Airways Inc. | 9,446 |
| 5 | EV | ExpressJet Airlines Inc. | 8,823 |
| 6 | AA | American Airlines Inc. | 5,433 |
| 7 | WN | Southwest Airlines Co. | 4,726 |
| 8 | 9E | Endeavor Air Inc. | 3,784 |
| 9 | VX | Virgin America | 2,518 |
| 10 | FL | AirTran Airways Corporation | 904 |
| 11 | AS | Alaska Airlines Inc. | 358 |
| 12 | HA | Hawaiian Airlines Inc. | 353 |
| 13 | F9 | Frontier Airlines Inc. | 313 |
| 14 | YV | Mesa Airlines Inc. | 143 |
| 15 | MQ | Envoy Air | 36 |
| 16 | OO | SkyWest Airlines Inc. | 7 |

**Data quality:** Every flight in the supplied file matched a `tailnum` in `nyc_planes.csv`; no flight's nominal seat count was lost to the aircraft lookup.

### 9. What is the most common airplane manufacturer?

**Primary answer: BOEING, with 1,630 registered aircraft** in `nyc_planes.csv`.

This is a fleet-record count, grouping by manufacturer and counting distinct `tailnum`. Manufacturer labels such as `AIRBUS` and `AIRBUS INDUSTRIE` appear separately as stored; consider standardization for any broader group comparison.

**Alternative interpretation — most flight operations by manufacturer:** BOEING also leads, with **80,345 flight records** joined to Boeing aircraft. This is a different denominator from fleet size.

### 10. What is the most common airplane model?

**Primary answer: `737-7H4`, with 361 registered aircraft** in `nyc_planes.csv`.

**Alternative interpretation — most frequently operated model:** `A320-232`, with **42,423 flight records**. Explain the difference between **most common airframe in the aircraft register** and **most frequently flown model**.

## Power BI implementation

### Recommended model

Build a **flight fact table** plus reference dimensions:

- `nyc_flights_fixed` (fact) → `nyc_airlines` on `carrier` (*:1)
- `nyc_flights_fixed` (fact) → `nyc_planes` on `tailnum` (*:1)
- `nyc_flights_fixed` (fact) → `dim_calendar` on a derived date (*:1)
- `nyc_flights_fixed` (fact) → `nyc_weather` on a **combined `origin + time_hour` key** (*:1)
- `nyc_airports` can be used as an airport lookup for origin/destination labels; role-playing relationships may be required to avoid ambiguous paths.

Create a local date in the flight table using `DATE([year], [month], [day])` and a day-of-week column in the calendar. Set weekday sorting via a numeric weekday index (Monday = 1 to Sunday = 7). Since the CSV `time_hour` values use `Z` (UTC), **normalize the type and timezone consistently** in both tables before constructing the join key. Prefer performing composite key creation and type cleanup in Power Query.

### DAX measures

```dax
Total Flights =
COUNTROWS(nyc_flights_fixed)

Distinct Destinations =
DISTINCTCOUNT(nyc_flights_fixed[dest])

Avg Daily Distinct Destinations =
AVERAGEX(
    VALUES(dim_calendar[Date]),
    [Distinct Destinations]
)

Avg Daily Distinct Destinations (Rounded) =
ROUND([Avg Daily Distinct Destinations], 0)

Net Departure Delay (Minutes) =
SUM(nyc_flights_fixed[dep_delay])

Positive Departure Delay (Minutes) =
SUMX(
    nyc_flights_fixed,
    MAX(nyc_flights_fixed[dep_delay], 0)
)

Average Departure Delay (Minutes) =
AVERAGE(nyc_flights_fixed[dep_delay])

Seats Offered =
SUMX(
    nyc_flights_fixed,
    RELATED(nyc_planes[seats])
)

Average Daily Seats Offered =
AVERAGEX(
    VALUES(dim_calendar[Date]),
    COALESCE([Seats Offered], 0)
)

Registered Aircraft =
DISTINCTCOUNT(nyc_planes[tailnum])
```

**Measure notes:**

- The weekday average uses **unrounded** daily destination counts; only round for display when requested.
- `Average Daily Seats Offered` averages across dates in the current calendar filter, counting days without flights as zero. For the full 2013 dataset, the denominator is 365. If the requirement instead means average **only on days when a carrier operated flights**, change the denominator and document the distinction.
- The `Registered Aircraft` measure describes all records in the planes dataset. If you need manufacturers/models **only among aircraft that operated a flight** in the filtered flight set, create a separate explicitly flight-scoped measure rather than assuming filters propagate from flights back to planes.
- The rain/dry comparison can use a weather classification column (`precip > 0`), but **exclude unmatched weather** rather than classifying missing values as dry.

### Suggested Power BI report pages

| Page | Questions | Suggested visuals |
|---|---|---|
| **Flight Operations** | 1–5 | Distinct destinations KPI, average daily destinations KPI, weekday bar chart, monthly flight chart, monthly net/positive delay chart |
| **Weather Impact** | 6 | Rain vs dry delay KPI/bar chart, weather-variable correlations, scatter plots and explanatory tooltip |
| **Airlines & Fleet** | 7–10 | Flights by airline ranking, seats/day by airline ranking, manufacturer and model tables with clear definitions |

### Validation checklist

- [ ] Total flights = **277,977** and dates = **365**.
- [ ] Annual distinct destinations = **100**.
- [ ] Average daily distinct destinations ≈ **81.0767**.
- [ ] August flights = **24,290**.
- [ ] July net delay = **535,995 minutes**; positive-only delay = **583,738 minutes**.
- [ ] Weather matches = **276,688**; unmatched = **1,289**.
- [ ] All flights match an aircraft row on `tailnum`.
- [ ] Airline flight ranking is not affected by duplicating rows during joins.
- [ ] Daily seat capacity uses **one seat count per flight**, not one per aircraft.
- [ ] Manufacturer/model rankings state whether they use **aircraft records** or **flight records**.

## Conclusions

Across the supplied 2013 NYC departure records, **August** had the largest number of flights while **July** had the highest cumulative departure delay. **Sunday** showed the broadest average daily destination coverage. **United Air Lines** led both flight volume and nominal seats offered per day. Rainy observations were associated with substantially higher average departure delays, although simple linear correlations with individual weather variables remained weak. **Boeing** was the most common manufacturer in the aircraft reference table; the **737-7H4** was the most common registered model, while the **A320-232** was the most frequently operated model.
