SELECT
    u.index_name,
    i.table_name,
    u.used,
    u.start_monitoring,
    u.end_monitoring
FROM
    v$object_usage u
JOIN
    user_indexes i
ON
    i.index_name = u.index_name
ORDER BY
    i.table_name,
    u.index_name;

