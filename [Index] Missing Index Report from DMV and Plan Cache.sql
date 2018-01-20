	-- For all DBs, comment out 
			--"OBJECT_NAME(mid.[object_id] ,@Dbid) AS Objname" on Line 8
			--"AND mid.database_id = (SELECT DB_ID(@Dbname))" on Line 35
	DECLARE @Dbid INT = DB_ID('HCHB_LHC'); 
	
    SELECT

      OBJECT_NAME(mid.[object_id] ,@Dbid) AS Objname --comment this out when querying for multi-DBs
      
      , migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,

      'CREATE INDEX [missing_index_' + CONVERT (varchar, mig.index_group_handle) + '_' + CONVERT (varchar, mid.index_handle)

      + '_' + LEFT (PARSENAME(mid.statement, 1), 32) + ']'

      + ' ON ' + mid.statement

      + ' (' + ISNULL (mid.equality_columns,'')

        + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END

        + ISNULL (mid.inequality_columns, '')

      + ')'

      + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,

      migs.*, mid.database_id
      , mid.[object_id]

    FROM sys.dm_db_missing_index_groups mig WITH (NOLOCK)

    INNER JOIN sys.dm_db_missing_index_group_stats migs  WITH (NOLOCK) ON migs.group_handle = mig.index_group_handle

    INNER JOIN sys.dm_db_missing_index_details mid WITH (NOLOCK) ON mig.index_handle = mid.index_handle AND mid.database_id = @Dbid

    WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10

	--AND OBJECT_NAME(mid.[object_id] ,@Dbid) LIKE '%mytable%'

    ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC
	GO

-- Find missing index warnings for cached plans
-- Note: This query could take some time on a busy instance

	DECLARE @Dbid INT = DB_ID('HCHB_LHC'); 

	SELECT TOP(25) OBJECT_NAME(objectid) AS [ObjectName], 
				   query_plan, cp.objtype, cp.usecounts
	FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
	WHERE CAST(query_plan AS NVARCHAR(MAX)) LIKE N'%MissingIndex%'
	AND dbid = @Dbid
	--AND OBJECT_NAME([objectid] ,@Dbid) LIKE '%mytable%'
	ORDER BY cp.usecounts DESC OPTION (RECOMPILE);

	GO