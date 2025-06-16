CREATE TABLE IF NOT EXISTS default.departments
(
    dept_no String,
    dept_name String,
    __deleted Bool,
    __source_ts_ms Int64
)
ENGINE = ReplacingMergeTree()
PRIMARY KEY dept_no
ORDER BY dept_no
-- to drop the row with __deleted = true, manually run : OPTIMIZE TABLE default.departments FINAL CLEANUP;
SETTINGS allow_experimental_replacing_merge_with_cleanup=1;
