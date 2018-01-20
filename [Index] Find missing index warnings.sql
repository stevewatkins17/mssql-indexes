if not exists(
	select 1 from dba_admin.sys.objects o join dba_admin.sys.schemas s on s.schema_id = o.schema_id 
	and o.name = 'MissingIdxWarnings' and s.name = 'dbo'
)
begin
	create table dba_admin.dbo.MissingIdxWarnings(
	 rid int identity(1,1) 
	,[objectid] int
	,[ObjectName] nvarchar(128) 
	,[query_plan] xml
	,[objtype] nvarchar(128) 
	,[usecounts] int
	);
end


-- Find missing index warnings for cached plans in the current database
-- Note: This query could take some time on a busy instance

	declare @topn int = 25;

	insert dba_admin.dbo.MissingIdxWarnings
	SELECT TOP(@topn) 
		 qp.objectid
		,[ObjectName] = OBJECT_NAME(qp.objectid)
		,qp.[query_plan]
		,cp.[objtype]
		,cp.[usecounts]
	FROM sys.dm_exec_cached_plans cp WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
	WHERE 1=1
	AND CAST(query_plan AS NVARCHAR(MAX)) LIKE N'%MissingIndex%'
	AND dbid = DB_ID()
	ORDER BY cp.usecounts DESC 
	OPTION (RECOMPILE);

GO

/*
select * from dba_admin.dbo.MissingIdxWarnings

USE [DBA_ADMIN]
GO

DROP TABLE [dbo].[MissingIdxWarnings]
GO

*/