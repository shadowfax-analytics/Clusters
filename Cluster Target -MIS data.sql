SELECT
    order_table.*,
    attendance_table.FTE_Days,
    attendance_table.LWAs,
    attendance_table.OT,
    attendance_table.KM_Not_FTEs,
    attendance_table.KMs
FROM
(
    SELECT
        d.city AS `City`,
d.operational_city AS 'Operational City',
        d.cluster_name AS `Cluster Name`,
        a.cluster_id AS `Cluster ID`,
        day(date(convert_tz(a.order_time,"UTC","Asia/Kolkata"))) AS `Order Day`,
        CONCAT(day(date(convert_tz(a.order_time,"UTC","Asia/Kolkata"))), "-", a.cluster_id) AS `or_primary_key`,
        COUNT(a.id) AS Orders,
        FLOOR(SUM(
            CASE
                WHEN e.delivery_charge < 50000
                THEN e.delivery_charge
                ELSE 0
            END)) AS Revenue,
        SUM(CASE WHEN c.store_type = 'F&B' THEN 1 ELSE 0 END) AS `F&B Orders`,
        SUM(CASE WHEN c.store_type = 'Ecom' THEN 1 ELSE 0 END) AS `Ecom Orders`,
        SUM(CASE WHEN c.store_type = 'NonPriority' THEN 1 ELSE 0 END) AS `NonPriority Orders`,
        FLOOR(SUM(
            CASE
                WHEN c.store_type = 'F&B' AND e.delivery_charge < 50000
                THEN e.delivery_charge
                ELSE 0
            END)) AS `F&B Revenue`,
        FLOOR(SUM(
            CASE
                WHEN c.store_type = 'Ecom' AND e.delivery_charge < 50000
                THEN e.delivery_charge
                ELSE 0
            END)) AS `Ecom Revenue`,
        FLOOR(SUM(
            CASE
                WHEN c.store_type = 'NonPriority' AND e.delivery_charge < 50000
                THEN e.delivery_charge
                ELSE 0
            END)) AS `NonPriority Revenue`,
        SUM(CASE WHEN e.delivery_charge != 0 THEN 1 ELSE 0 END) AS `Positive Revenue Orders`,
        SUM(CASE WHEN e.calculation_method IN ('Free Order', 'Leakage') THEN 1 ELSE 0 END) AS `Free Orders`,
        SUM(
            CASE
                WHEN e.delivery_charge != 0
                THEN 0
                WHEN e.calculation_method IN ('Free Order', 'Leakage')
                THEN 0
                ELSE 1
            END) AS `No Detail Orders`,
        SUM(CASE WHEN a.issue != -1 THEN 1 ELSE 0 END) AS `Seller Issues`,
        SUM(CASE WHEN a.cancel_reason IN (1,2,4) THEN 1 ELSE 0 END) AS `Cancelled Orders`,
        SUM(CASE WHEN a.source NOT IN (1,2) THEN 1 ELSE 0 END) AS `Seller Orders`,
        SUM(
            CASE
                WHEN a.accepted_flag = 1 OR a.delivered_flag = 1 OR a.pickup_flag = 1
                THEN 1
                ELSE 0
            END) AS `App Orders`,
        SUM(
            CASE
                WHEN
                    (TIME_TO_SEC(a.allot_time) - TIME_TO_SEC(a.order_time) > 0) AND
                    (TIME_TO_SEC(a.allot_time) - TIME_TO_SEC(a.order_time) < 300)
                THEN 1
                ELSE 0
            END) AS `5 Mins Allotment`
    FROM coreengine_order a
    INNER JOIN coreengine_sfxseller AS b ON a.seller_id = b.id
    INNER JOIN coreengine_sellerprofile AS c ON b.seller_id = c.id
    INNER JOIN coreengine_chain AS ch ON ch.id = b.chain_id
    INNER JOIN coreengine_cluster AS d ON a.cluster_id = d.id
    LEFT JOIN order_charges AS e ON e.order_id = a.id
    WHERE
        a.amount < 500000
        AND d.cluster_name not like "%Test%"
        AND a.status < 6
        AND date(convert_tz(a.order_time,"UTC","Asia/Kolkata")) = adddate(curdate(),-1)
        GROUP BY
        d.city,
        d.cluster_name
        #day(date(convert_tz(a.order_time,"UTC","Asia/Kolkata")))
    LIMIT 10000000
) AS order_table
INNER JOIN 
(
    SELECT
        d.city AS `City`,
        d.cluster_name AS `Cluster Name`,
        a.cluster_id,
        day(a.attendancedate) AS `Day`,
        CONCAT(day(a.attendancedate), "-", a.cluster_id) AS `at_primary_key`,
        CEIL(SUM(
            CASE
                WHEN a.status = 0 && c.role = 'FT'
                THEN 1
                WHEN a.status = 0 && c.role = 'PRT'
                THEN 0.5
                ELSE 0
            END)) AS `FTE_Days`,
        CEIL(SUM(
            CASE
                WHEN a.status = 2 && c.role = 'FT'
                THEN 1
                WHEN a.status = 2 && c.role = 'PRT'
                THEN 0.5
                ELSE 0
            END)) AS `LWAs`,
        CEIL(SUM(
            CASE
                WHEN a.status = 0 && c.role = 'FT' && a.kilometer = 0
                THEN 1
                WHEN a.status = 0 && c.role = 'PRT' && a.kilometer = 0
                THEN 0.5
                ELSE 0
            END)) AS `KM_Not_FTEs`,
        CEIL(SUM(
            CASE
                WHEN
                    c.role = 'FT'
                    AND CEIL((TIME_TO_SEC(actual_outtime) - TIME_TO_SEC(actual_intime))/3600 - 9) IN (1,2,3,4)
                THEN CEIL((TIME_TO_SEC(actual_outtime) - TIME_TO_SEC(actual_intime))/3600 - 9)
                WHEN
                    c.role = 'PRT'
                    AND CEIL((TIME_TO_SEC(actual_outtime) - TIME_TO_SEC(actual_intime))/3600 - 4) IN (1,2,3,4)
                THEN CEIL((TIME_TO_SEC(actual_outtime) - TIME_TO_SEC(actual_intime))/3600 - 4)
                ELSE 0
            END)) AS `OT`,
        SUM(a.kilometer) AS `KMs`
    FROM coreengine_riderattendance a
    INNER JOIN coreengine_sfxrider b on b.id = a.rider_id
    INNER JOIN coreengine_riderprofile c on c.id = b.rider_id
    INNER JOIN coreengine_cluster d on a.cluster_id = d.id
    WHERE
        d.cluster_name NOT LIKE "%Test%"
        AND a.attendance_record > 0
        AND attendancedate = adddate(curdate(),-1)
    GROUP BY day(attendancedate), d.id
    LIMIT 10000000
) AS attendance_table
ON attendance_table.at_primary_key = order_table.or_primary_key