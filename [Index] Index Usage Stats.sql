--USE HCHB_BAYADA
--GO

/*

select * from sys.indexes where name = 'ix_myidx'


select 
	 [Stats Updated] = STATS_DATE(object_id, index_id)  
	,[table name] = object_name(object_id)
	,[index name] = name
from sys.indexes where name in('ix_myidx')


*/


DECLARE @ObjName VARCHAR(128) = '[dbo].[mytable]';

DECLARE @IDXName VARCHAR(128) = null
DECLARE @dbid INT = DB_ID();
DECLARE @ObjID INT = object_id(@ObjName);
DECLARE @IDX_ID INT = (SELECT index_id FROM sys.indexes
						WHERE object_id = @ObjID
						AND name = @IDXName);

IF @ObjID IS NULL --OR @IDX_ID IS NULL
	PRINT'Table does not exist'
ELSE

	BEGIN
		SELECT 
			   b.[name]
			  ,b.[type_desc]
			  ,[usability] = 
				  CASE WHEN a.[user_updates] = 0 THEN (a.[user_seeks] + a.[user_scans])
				  ELSE CAST( ROUND( ((CAST( (a.[user_seeks] + a.[user_scans]) AS DECIMAL(19,2))/(a.[user_updates]) ) *100) ,2) AS FLOAT)
				  END
			  ,fn.IndexSizeMB
			  ,b.[is_unique]
			  ,a.[user_seeks]
			  ,a.[user_scans]
			  ,a.[user_lookups]
			  ,a.[user_updates]
			  ,a.[last_user_seek]
			  ,a.[last_user_scan]
			  ,a.[last_user_lookup]
			  ,a.[last_user_update]
			  ,a.[system_seeks]
			  ,a.[system_scans]
			  ,a.[system_lookups]
			  ,a.[system_updates]
			  ,a.[last_system_seek]
			  ,a.[last_system_scan]
			  ,a.[last_system_lookup]
			  ,a.[last_system_update]
			  ,b.[data_space_id]
			  ,b.[ignore_dup_key]
			  ,b.[is_primary_key]
			  ,b.[is_unique_constraint]
			  ,b.[fill_factor]
			  ,b.[is_padded]
			  ,b.[is_disabled]
			  ,b.[is_hypothetical]
			  ,b.[allow_row_locks]
			  ,b.[allow_page_locks]
			  ,b.[has_filter]
			  ,b.[filter_definition]
			  --,b.[index_id]
			  --,b.[type]
		FROM sys.dm_db_index_usage_stats a
		JOIN sys.indexes b ON a.index_id = b.index_id  
		AND b.index_id = @IDX_ID AND a.index_id = @IDX_ID
			AND a.database_id = @dbid
			AND a.object_id = @ObjID
			AND b.object_id = @ObjID
		outer apply(
			SELECT IndexSizeMB = (SUM(s.[used_page_count]) * 8) / 1024 
			FROM sys.dm_db_partition_stats AS s
			INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
				AND s.[index_id] = i.[index_id]
			 where OBJECT_SCHEMA_NAME(i.object_id) <> 'sys'
			 and OBJECT_SCHEMA_NAME(i.object_id) = OBJECT_SCHEMA_NAME(@ObjID)
			 and OBJECT_NAME(i.object_id) = @ObjName
			 and i.[name] = b.[name]
			GROUP BY i.object_id ,i.[name]
		) fn
--		ORDER BY [usability] DESC
		ORDER BY 1 ASC
		
		SELECT 
		 IndexName = ISNULL(i.[name] ,'<Total Size>') 
		,IndexSizeMB = (SUM(s.[used_page_count]) * 8)/1024 
		FROM sys.dm_db_partition_stats AS s
		INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
			AND s.[index_id] = i.[index_id]
			AND i.name = @IDX_ID
			AND s.[object_id] = @ObjID --OBJECT_ID('dbo.client_episodes_visit_notes')
		GROUP BY i.[name] WITH ROLLUP
		ORDER BY 2 ASC
	
/* All IDXes */
	--SELECT 
	-- TableName = OBJECT_NAME(s.[object_id]) 
	--,IndexName = i.[name]
 --   ,IndexSizeMB = (SUM(s.[used_page_count]) * 8)/1024 
	--FROM sys.dm_db_partition_stats AS s
	--INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id]
	--	AND s.[index_id] = i.[index_id]
	--	AND i.name = @IDX_ID
	--	AND s.[object_id] = @ObjID --OBJECT_ID('dbo.client_episodes_visit_notes')
	--WHERE i.[name] IS NOT NULL
	--GROUP BY s.[object_id] ,i.[name]
	--ORDER BY 3 desc ,1 ,2 ASC

	
END


/*
with TabIndexes as (
	select schema_name(o.schema_id) + '.' + OBJECT_NAME(i.object_id) as TableName
		,i.index_id as IndexId
		,i.name as IndexName
		,pt.IndexSize_KB
		,st.User_Seeks, st.user_scans, st.user_lookups, st.user_updates
		,case i.type when 0 then 'HEP' when 1 then 'CLS' when 2 then 'NCL' end as IndexType
		,i.is_primary_key as PK
		,i.is_unique_constraint as UK 
		,i.is_unique as IsUnique
		,ckey.cols as KeyColumns
		,ikey.cols as IncludeColumns
		,i.has_filter as Filter
		,i.filter_definition as FilterDefn
		,cmpKey.cols as CompareCols
	FROM sys.indexes i join sys.objects o on i.object_id = o.object_id and (o.type = 'U' or o.type = 'V')
	LEFT JOIN sys.objects pk ON o.object_id = pk.object_id and pk.parent_object_id = i.object_id AND pk.[type] = 'pk'
	LEFT JOIN sys.objects uk ON o.object_id = uk.object_id and uk.parent_object_id = i.object_id AND uk.[type] = 'uq'
	left join sys.dm_db_index_usage_stats st on st.object_id = i.object_id
		and st.index_id = i.index_id and st.database_id = db_id()
	left join (select object_id, index_id, SUM(used_page_count) * 8 as IndexSize_KB 
			   from sys.dm_db_partition_stats
			   group by object_id, index_id) pt on pt.object_id = i.object_id and pt.index_id = i.index_id
	OUTER APPLY (
			SELECT STUFF((SELECT ',' + c.name + CASE is_descending_key WHEN 1 THEN ' desc' else '' END
			FROM sys.index_columns ic
				INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
			WHERE ic.index_id = i.index_id 
				AND ic.object_id = i.object_id
				AND ic.is_included_column = 0 --this column is not included
			ORDER BY ic.key_ordinal --order by the way it was entered
			FOR XML PATH('')),1,1,'')
	) ckey(cols)
	OUTER APPLY	(
			SELECT STUFF((SELECT ',' + c.name
			FROM sys.index_columns ic
				INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
			WHERE ic.index_id = i.index_id
				AND ic.object_id = i.object_id
				AND ic.is_included_column = 1 --column is included
			ORDER BY ic.key_ordinal --order by way it was entered
			FOR XML PATH('')),1,1,'')
	) ikey(cols)
	OUTER APPLY	(
			SELECT STUFF((SELECT ',' + c.name
			FROM sys.index_columns ic
				INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
			WHERE ic.index_id = i.index_id
				AND ic.object_id = i.object_id
				AND ic.is_included_column = 0 
			ORDER BY c.column_id --order by way it was entered
			FOR XML PATH('')),1,1,'')
	) cmpkey(cols)
	WHERE	i.is_disabled = 0 --Index is not disabled
	--and o.object_id = object_id('SYSTEM_SETTING_REPORTSERVER_REPORTS')
)
select TableName	--,CompareCols 
	,indexId, IndexName, IndexSize_KB
	,User_Seeks, user_scans, user_lookups, user_updates
	,IndexType, PK, UK, IsUnique
	,KeyColumns,IncludeColumns, Filter, FilterDefn
from (
	select TableName, CompareCols, 
		count(*) over (partition by TableName, KeyColumns) as cnt
		,indexId, IndexName, IndexSize_KB
		,User_Seeks, user_scans, user_lookups, user_updates
		,IndexType, PK, UK, IsUnique
		,KeyColumns,IncludeColumns, Filter, FilterDefn
	from TabIndexes 
	where indexId > 1) t 
where t.cnt > 1 ;

*/
	
