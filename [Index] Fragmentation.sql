--:connect myinstance

declare @DBID int = db_id('myDB')

SELECT
      ps.database_id
    , ps.OBJECT_ID AS objectID
    , ps.index_id AS indexID
    , ps.partition_number AS partitionNumber
    , ps.avg_fragmentation_in_percent AS fragmentation
    , ps.page_count
    , GETDATE() AS [EffectiveDate]
FROM sys.dm_db_index_physical_stats (@DBID, NULL, NULL , NULL, N'Limited') ps
WHERE /*ps.database_id = @DBID
AND */ps.index_id > 0 
   AND ps.page_count > 1000 
order by ps.avg_fragmentation_in_percent DESC
OPTION (MaxDop 1);