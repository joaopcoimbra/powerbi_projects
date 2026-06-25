WITH base_visits_1_temp AS (
    SELECT
        COUNTRY,
        VENDOR_ACCOUNT_ID,
        VENDOR_ID,
        VISIT_DATE,
        PLANNED_VISIT,
        VISITED
    FROM ahi_am.sandbox.base_visits_grow
    WHERE visit_date >= '2025-01-01'
      AND visit_date <= date_sub(current_date(), 1)
      AND (
            country != 'MX'
            OR (country = 'MX' AND VENDOR_ACCOUNT_ID NOT LIKE '4%')
          )
),

base_visits_1_temp_1 AS (
    SELECT
        *,
        date_format(VISIT_DATE, 'EEEE') AS DAY_WEEK
    FROM base_visits_1_temp
    WHERE VISITED = 0
),

base_visits_2_temp AS (
    SELECT
        COUNTRY,
        VENDOR_ACCOUNT_ID,
        VENDOR_ID,
        VISIT_DATE,
        PLANNED_VISIT,
        VISITED
    FROM ahi_am.sandbox.base_visits_grow_cancelled_called
    WHERE visit_date >= '2025-01-01'
      AND visit_date <= date_sub(current_date(), 2)
      AND (
            country != 'MX'
            OR (country = 'MX' AND VENDOR_ACCOUNT_ID NOT LIKE '4%')
          )
),

base_visits_2_temp_1 AS (
    SELECT
        *,
        date_format(VISIT_DATE, 'EEEE') AS DAY_WEEK
    FROM base_visits_2_temp
    WHERE VISITED = 0
),

base_visits_2 AS (
    SELECT * FROM base_visits_1_temp_1
    UNION
    SELECT * FROM base_visits_2_temp_1
),

calls AS (
    SELECT
        *,
        CAST(split(service_duration, ':')[0] AS INT) * 3600
            + CAST(split(service_duration, ':')[1] AS INT) * 60
            + CAST(split(service_duration, ':')[2] AS INT) AS call_duration
    FROM grw_am.silver_analytics.fact_calls_and_cti
    WHERE call_typification != 'In_Queue'
),

calls_silver AS (
    SELECT
        *,
        CASE
            WHEN source = 'Regular Call'
                 AND strike = 1
                THEN 1
            WHEN source IN ('CTI', 'Merged')
                 AND call_duration >= 60
                 AND call_typification NOT IN (
                     'Answer_Machine',
                     'Attempt_Timeout',
                     'Desktop_Error',
                     'Disconnected_By_System',
                     'Network_Refusal',
                     'No_Answer',
                     'Ring_No_Answer',
                     'Transferencia Care con venta',
                     'Transferencia Care sin venta'
                 )
                THEN 1
            ELSE 0
        END AS effective_hit
    FROM calls
),

calls_gold_tz AS (
    SELECT
        COUNTRY,
        VENDOR_ID,
        POC_ID,
        DATE_TZ,
        MIN(START_CALL_DATE_TZ) AS FIRST_CALL_DAY_TZ,
        MIN(CASE WHEN effective_hit = 1 THEN START_CALL_DATE_TZ END) AS FIRST_EFFECTIVE_HIT_DAY_TZ
    FROM calls_silver
    GROUP BY 1, 2, 3, 4
),

base_join AS (
    SELECT
        base_visits_2.*,
        calls_gold_tz.FIRST_CALL_DAY_TZ,
        calls_gold_tz.FIRST_EFFECTIVE_HIT_DAY_TZ
    FROM base_visits_2
    LEFT JOIN calls_gold_tz
        ON base_visits_2.COUNTRY = calls_gold_tz.COUNTRY
        AND base_visits_2.VENDOR_ID = calls_gold_tz.VENDOR_ID
        AND base_visits_2.VENDOR_ACCOUNT_ID = calls_gold_tz.POC_ID
        AND TO_DATE(calls_gold_tz.FIRST_CALL_DAY_TZ) BETWEEN base_visits_2.VISIT_DATE
            AND CASE
                    WHEN base_visits_2.DAY_WEEK = 'Saturday'
                        THEN DATE_ADD(base_visits_2.VISIT_DATE, 2)
                    WHEN base_visits_2.COUNTRY IN ('ES', 'GH', 'UG', 'ZA')
                         AND base_visits_2.DAY_WEEK = 'Friday'
                        THEN DATE_ADD(base_visits_2.VISIT_DATE, 3)
                    ELSE DATE_ADD(base_visits_2.VISIT_DATE, 1)
                END
),

base_vendor AS (
    SELECT
        vendor_id,
        is_abi,
        display_name
    FROM wh_am.gold.dim_vendor
),

base_join_1 AS (
    SELECT
        base_join.*,
        base_vendor.is_abi,
        base_vendor.display_name
    FROM base_join
    LEFT JOIN base_vendor USING (vendor_id)
),

base_join_2 AS (
    SELECT *
    FROM base_join_1
    WHERE is_abi = TRUE
      AND COUNTRY IN (
          'CO', 'DO', 'ES', 'HN', 'MX', 'PA', 'PE',
          'PY', 'SV', 'ZA', 'EC', 'GH', 'TZ', 'UG'
      )
),

base_orders_pre AS (
    SELECT
        *,
        CASE
            WHEN COUNTRY = 'AR' THEN convert_timezone('UTC', 'America/Buenos_Aires',  COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'CO' THEN convert_timezone('UTC', 'America/Bogota',        COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'DO' THEN convert_timezone('UTC', 'America/Santo_Domingo', COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'EC' THEN convert_timezone('UTC', 'America/Guayaquil',     COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'ES' THEN convert_timezone('UTC', 'Europe/Madrid',         COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'HN' THEN convert_timezone('UTC', 'America/Tegucigalpa',   COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'MX' THEN convert_timezone('UTC', 'America/Mexico_City',   COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'PA' THEN convert_timezone('UTC', 'America/Panama',        COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'PE' THEN convert_timezone('UTC', 'America/Lima',          COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'SV' THEN convert_timezone('UTC', 'America/El_Salvador',   COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'PY' THEN convert_timezone('UTC', 'America/Asuncion',      COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'ZA' THEN convert_timezone('UTC', 'Africa/Johannesburg',   COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'TZ' THEN convert_timezone('UTC', 'Africa/Dar_es_Salaam',  COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'UG' THEN convert_timezone('UTC', 'Africa/Kampala',        COALESCE(placement_date, created_at_utc))
            WHEN COUNTRY = 'GH' THEN convert_timezone('UTC', 'Africa/Accra',          COALESCE(placement_date, created_at_utc))
            ELSE COALESCE(placement_date, created_at_utc)
        END AS datetime_order_tz
    FROM wh_am.gold.fact_orders
),

base_orders AS (
    SELECT
        COUNTRY,
        VENDOR_ID,
        COALESCE(VENDOR_ACCOUNT_ID, ACCOUNT_ID) AS POC_ID,
        CURRENT_STATUS,
        CURRENT_CHANNEL,
        ORDER_NUMBER,
        datetime_order_tz AS DATETIME_ORDER,
        CURRENT_TOTAL AS TOTAL_REV
    FROM base_orders_pre
    WHERE VENDOR_ACCOUNT_ID IS NOT NULL
      AND CURRENT_CHANNEL IN ('B2B_APP', 'B2B_LNK', 'B2B_WEB', 'CX_TLP', 'B2B_FORCE')
      AND CURRENT_TOTAL > 0
),

base_join_3 AS (
    SELECT
        base_join_2.*,
        base_orders.ORDER_NUMBER,
        base_orders.DATETIME_ORDER
    FROM base_join_2
    LEFT JOIN base_orders
        ON base_join_2.COUNTRY = base_orders.COUNTRY
        AND base_join_2.VENDOR_ID = base_orders.VENDOR_ID
        AND base_join_2.VENDOR_ACCOUNT_ID = base_orders.POC_ID
        AND base_orders.DATETIME_ORDER BETWEEN CAST(base_join_2.VISIT_DATE AS TIMESTAMP)
            AND DATE_ADD(DATE_TRUNC('DAY', CAST(base_join_2.VISIT_DATE AS TIMESTAMP)), 1) - INTERVAL 1 SECOND
),

base_join_4 AS (
    SELECT
        VENDOR_ID,
        COUNTRY,
        VENDOR_ACCOUNT_ID,
        VISIT_DATE,
        DAY_WEEK,
        PLANNED_VISIT,
        VISITED,
        FIRST_CALL_DAY_TZ,
        FIRST_EFFECTIVE_HIT_DAY_TZ,
        is_abi,
        display_name,
        COUNT(DISTINCT ORDER_NUMBER) AS TOT_ORDERS_SAME_DAY_FAILED_VISIT
    FROM base_join_3
    GROUP BY ALL
),

base_join_5 AS (
    SELECT
        base_join_4.*,
        base_orders.ORDER_NUMBER,
        base_orders.DATETIME_ORDER
    FROM base_join_4
    LEFT JOIN base_orders
        ON base_join_4.COUNTRY = base_orders.COUNTRY
        AND base_join_4.VENDOR_ID = base_orders.VENDOR_ID
        AND base_join_4.VENDOR_ACCOUNT_ID = base_orders.POC_ID
        AND base_orders.DATETIME_ORDER BETWEEN CAST(base_join_4.VISIT_DATE AS TIMESTAMP)
            AND base_join_4.FIRST_EFFECTIVE_HIT_DAY_TZ
),

base_join_6 AS (
    SELECT
        VENDOR_ID,
        COUNTRY,
        VENDOR_ACCOUNT_ID,
        VISIT_DATE,
        DAY_WEEK,
        PLANNED_VISIT,
        VISITED,
        FIRST_CALL_DAY_TZ,
        FIRST_EFFECTIVE_HIT_DAY_TZ,
        is_abi,
        display_name,
        TOT_ORDERS_SAME_DAY_FAILED_VISIT,
        COUNT(DISTINCT ORDER_NUMBER) AS TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT
    FROM base_join_5
    GROUP BY ALL
),

base_join_7 AS (
    SELECT
        base_join_6.*,
        base_orders.ORDER_NUMBER,
        base_orders.DATETIME_ORDER
    FROM base_join_6
    LEFT JOIN base_orders
        ON base_join_6.COUNTRY = base_orders.COUNTRY
        AND base_join_6.VENDOR_ID = base_orders.VENDOR_ID
        AND base_join_6.VENDOR_ACCOUNT_ID = base_orders.POC_ID
        AND base_orders.DATETIME_ORDER BETWEEN CAST(base_join_6.VISIT_DATE AS TIMESTAMP)
            AND (
                CASE
                    WHEN base_join_6.DAY_WEEK = 'Saturday'
                        THEN DATE_ADD(DATE_TRUNC('DAY', CAST(base_join_6.VISIT_DATE AS TIMESTAMP)), 3)
                    WHEN base_join_6.COUNTRY IN ('ES', 'GH', 'UG', 'ZA')
                         AND base_join_6.DAY_WEEK = 'Friday'
                        THEN DATE_ADD(DATE_TRUNC('DAY', CAST(base_join_6.VISIT_DATE AS TIMESTAMP)), 4)
                    ELSE DATE_ADD(DATE_TRUNC('DAY', CAST(base_join_6.VISIT_DATE AS TIMESTAMP)), 2)
                END
            ) - INTERVAL 1 SECOND
),

base_join_8 AS (
    SELECT
        VENDOR_ID,
        COUNTRY,
        VENDOR_ACCOUNT_ID,
        VISIT_DATE,
        DAY_WEEK,
        PLANNED_VISIT,
        VISITED,
        FIRST_CALL_DAY_TZ,
        FIRST_EFFECTIVE_HIT_DAY_TZ,
        is_abi,
        display_name,
        TOT_ORDERS_SAME_DAY_FAILED_VISIT,
        TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT,
        COUNT(DISTINCT ORDER_NUMBER) AS TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_NEXT_DAY
    FROM base_join_7
    GROUP BY ALL
),

base_join_9 AS (
    SELECT
        base_join_8.*,
        base_orders.ORDER_NUMBER,
        base_orders.DATETIME_ORDER,
        base_orders.CURRENT_CHANNEL
    FROM base_join_8
    LEFT JOIN base_orders
        ON base_join_8.COUNTRY = base_orders.COUNTRY
        AND base_join_8.VENDOR_ID = base_orders.VENDOR_ID
        AND base_join_8.VENDOR_ACCOUNT_ID = base_orders.POC_ID
        AND base_orders.DATETIME_ORDER BETWEEN base_join_8.FIRST_EFFECTIVE_HIT_DAY_TZ
            AND DATE_ADD(DATE_TRUNC('DAY', base_join_8.FIRST_EFFECTIVE_HIT_DAY_TZ), 1) - INTERVAL 1 SECOND
),

base_join_10 AS (
    SELECT
        VENDOR_ID,
        COUNTRY,
        VENDOR_ACCOUNT_ID,
        VISIT_DATE,
        DAY_WEEK,
        PLANNED_VISIT,
        VISITED,
        FIRST_CALL_DAY_TZ,
        FIRST_EFFECTIVE_HIT_DAY_TZ,
        is_abi,
        display_name,
        TOT_ORDERS_SAME_DAY_FAILED_VISIT,
        TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT,
        TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_NEXT_DAY,
        COUNT(DISTINCT
            CASE WHEN CURRENT_CHANNEL NOT IN ('B2B_FORCE') THEN ORDER_NUMBER END
        ) AS TOT_ORDERS_SAME_DAY_EFFECTIVE_HIT
    FROM base_join_9
    GROUP BY ALL
),

countries AS (
    SELECT
        COUNTRY,
        TO_DATE(DATE_TRUNC('MONTH', VISIT_DATE)) AS MONTH_YEAR,
        COUNT(DISTINCT CONCAT(VENDOR_ACCOUNT_ID, VISIT_DATE)) AS TOT_FAILED_VISITS_ALL,
        COUNT(DISTINCT
            CASE
                WHEN (
                        FIRST_EFFECTIVE_HIT_DAY_TZ IS NOT NULL
                        AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT = 0
                     )
                     OR (
                        FIRST_EFFECTIVE_HIT_DAY_TZ IS NULL
                        AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_NEXT_DAY = 0
                     )
                THEN CONCAT(VENDOR_ACCOUNT_ID, VISIT_DATE)
            END
        ) AS TOT_FAILED_VISITS,
        COUNT(DISTINCT
            CASE
                WHEN (
                        (
                            FIRST_EFFECTIVE_HIT_DAY_TZ IS NOT NULL
                            AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT = 0
                        )
                        OR (
                            FIRST_EFFECTIVE_HIT_DAY_TZ IS NULL
                            AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_NEXT_DAY = 0
                        )
                     )
                     AND FIRST_CALL_DAY_TZ IS NOT NULL
                THEN CONCAT(VENDOR_ACCOUNT_ID, VISIT_DATE)
            END
        ) AS TOT_FAILED_VISITS_CALLED,
        COUNT(DISTINCT
            CASE
                WHEN FIRST_EFFECTIVE_HIT_DAY_TZ IS NOT NULL
                     AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT = 0
                THEN CONCAT(VENDOR_ACCOUNT_ID, VISIT_DATE)
            END
        ) AS TOT_FAILED_VISITS_EFFECTIVE_HIT,
        COUNT(DISTINCT
            CASE
                WHEN FIRST_EFFECTIVE_HIT_DAY_TZ IS NOT NULL
                     AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT = 0
                     AND TOT_ORDERS_SAME_DAY_EFFECTIVE_HIT > 0
                THEN CONCAT(VENDOR_ACCOUNT_ID, VISIT_DATE)
            END
        ) AS TOT_FAILED_VISITS_EFFECTIVE_HIT_AND_CONVERTED
    FROM base_join_10
    GROUP BY ALL
    ORDER BY 1, 2
),

base_final AS (
    SELECT
        country,
        vendor_account_id,
        visit_date,
        visited,
        MIN(first_call_day_tz) AS call_timestamp,
        MIN(first_effective_hit_day_tz) AS effective_hit_timestamp,
        MAX(TOT_ORDERS_SAME_DAY_EFFECTIVE_HIT) AS tot_orders_same_day_effective_hit
    FROM base_join_10
    WHERE (
            (
                FIRST_EFFECTIVE_HIT_DAY_TZ IS NOT NULL
                AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_EFFECTIVE_HIT = 0
            )
            OR (
                FIRST_EFFECTIVE_HIT_DAY_TZ IS NULL
                AND TOT_ORDERS_BETWEEN_FAILED_VISIT_AND_NEXT_DAY = 0
            )
          )
    GROUP BY ALL
)

-- 🔻 SELECT FINAL AJUSTADO (renomes, novas colunas e formatações)
SELECT
    country,
    TO_DATE(DATE_TRUNC('MONTH', visit_date)) AS month,   -- 2ª coluna
    vendor_account_id AS POC,
    visit_date,
    CASE WHEN visited = 0 THEN 'NO' ELSE 'YES' END AS visited,
    TO_DATE(call_timestamp) AS called_date,
    CASE WHEN call_timestamp IS NULL THEN 'NO' ELSE 'YES' END AS called,
    TO_DATE(effective_hit_timestamp) AS Effective_Hit_date,
    CASE WHEN effective_hit_timestamp IS NULL THEN 'NO' ELSE 'YES' END AS Had_Effective_Hit
FROM base_final
WHERE visit_date >= '2025-10-01'
ORDER BY visit_date;
