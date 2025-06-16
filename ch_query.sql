CREATE TABLE IF NOT EXISTS default.departments
(
    dept_no String,
    dept_name String,
    __deleted Bool,
    __source_ts_ms Int64
)
ENGINE = ReplacingMergeTree(__source_ts_ms, __deleted)
PRIMARY KEY dept_no
ORDER BY dept_no
-- if the data is duplicated, run this query to perform de-duplication : OPTIMIZE TABLE default.departments FINAL CLEANUP;
SETTINGS allow_experimental_replacing_merge_with_cleanup=1;
