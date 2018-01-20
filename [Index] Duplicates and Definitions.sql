
/* get index definitions on a single table */

	begin
		declare @objectname varchar(128) = 'dbo.CLIENTS_ALL'

		select 
		 IndexName
		,KeyColumns 
		,IncludeColumns
		,FilterDefn
		,IndexType
		,PK
		,UK
		,IsUnique
		,Filter
		from [utility].[tvf_showindex](@objectname) t
		order by 2,3,4,1
	end
	GO


/* get index dups all tables */
	begin
	
	declare @Duplicates table(TableName varchar(128) ,KeyColumns varchar(2000) ,IncludeColumns varchar(2000) ,FilterDefn varchar(2000) );
	
	insert @Duplicates 
		select 
			 TableName = t.name
			,fn.KeyColumns
			,fn.IncludeColumns
			,fn.FilterDefn
		from sys.tables t
		cross apply
			(
				select distinct
					 IndexName
					,KeyColumns = isnull(KeyColumns ,'')
					,IncludeColumns = isnull(IncludeColumns ,'')
					,FilterDefn = isnull(FilterDefn ,'')
				from [utility].[tvf_showindex](t.name)
			) fn
		where t.[type] = 'U' 
		and t.[is_ms_shipped] = 0
		group by 
			 t.name
			,fn.KeyColumns
			,fn.IncludeColumns
			,fn.FilterDefn
		having
		count(*) > 1

		select * from @Duplicates
	end
	GO
	
/* get index near-dups ("include" delta) all tables */
	begin

	declare @cte_2 table(name varchar(128) ,KeyColumns varchar(2000) ,FilterDefn varchar(2000));
	declare @cte_3 table(name varchar(128) ,KeyColumns varchar(2000) ,IncludeColumns varchar(2000) ,FilterDefn varchar(2000));
	
	insert @cte_2 
		select 
			 t.name
			,fn.KeyColumns
			,fn.FilterDefn
		from sys.tables t
		cross apply
			(
				select distinct
					 IndexName
					,KeyColumns = isnull(KeyColumns ,'')
					,FilterDefn = isnull(FilterDefn ,'')
				from [utility].[tvf_showindex](t.name)
				--clustered indexes ("CLS") often have an NCL counterpart with different "include", which is normal and excluded here
				where IndexType = 'NCL' 
			) fn
		where t.[type] = 'U' 
		and t.[is_ms_shipped] = 0
		group by 
			 t.name
			,fn.KeyColumns
			,fn.FilterDefn
		having
		count(*) > 1

	insert @cte_3 
		select 
			 t.name
			,fn.KeyColumns
			,fn.IncludeColumns
			,fn.FilterDefn
		from sys.tables t
		cross apply
			(
				select distinct
					 IndexName
					,KeyColumns = isnull(KeyColumns ,'')
					,IncludeColumns = isnull(IncludeColumns ,'')
					,FilterDefn = isnull(FilterDefn ,'')
				from [utility].[tvf_showindex](t.name)
			) fn
		where t.[type] = 'U' 
		and t.[is_ms_shipped] = 0
		group by 
			 t.name
			,fn.KeyColumns
			,fn.IncludeColumns
			,fn.FilterDefn
		having
		count(*) > 1

		select * from @cte_2 cte_2 
		where not exists(
			select 1 from @cte_3 cte_3 where
					cte_2.KeyColumns = cte_3.KeyColumns
					and cte_2.FilterDefn = cte_3.FilterDefn
			)
	
	end
	GO
	
/* create TVF "[utility].[tvf_showindex]" (converts Sandeep's sp_TableIndexs w/ additional "distinct") */
	IF object_id('[utility].[tvf_showindex]') IS NULL
		EXEC('CREATE FUNCTION [utility].[tvf_showindex] (@P1 VARCHAR(MAX) = '''', @P2 CHAR(1) = '','') RETURNS TABLE WITH schemabinding AS RETURN SELECT 1 AS item')
	GO

	SET ANSI_NULLS ON
	GO
	SET QUOTED_IDENTIFIER ON
	GO

	ALTER FUNCTION [utility].[tvf_showindex] (@objectname varchar(128))
	RETURNS TABLE 
	AS
	RETURN
		select distinct DB_NAME() as DB
			,schema_name(o.schema_id) + '.' + OBJECT_NAME(i.object_id) as TableName, i.name as IndexName
			,case i.type when 0 then 'HEP' when 1 then 'CLS' when 2 then 'NCL' end as IndexType
			,i.is_primary_key as PK
			,i.is_unique_constraint as UK --i.type_desc as IndexType
			,i.is_unique as IsUnique
			,ckey.cols as KeyColumns
			,ikey.cols as IncludeColumns
			,i.has_filter as Filter
			,i.filter_definition as FilterDefn
			,sSql = case
				 when i.is_primary_key = 1 then
					'alter table ' + schema_name(o.schema_id) + '.' + object_name(o.object_id) + ' add constraint '+ QUOTENAME(pk.name) + ' primary key ' + case when i.[type] = 2 then 'nonclustered' when i.[type] = 1 then 'clustered' end + ' ('+ISNULL(ckey.cols,ikey.cols)+');' 
				 when i.is_unique_constraint =  1 then
					'alter table ' + schema_name(o.schema_id) + '.' + object_name(o.object_id) + ' add constraint '+ quotename(uk.name) + ' unique ' + case when i.[type] = 2 then 'nonclustered' when i.[type] = 1 then 'clustered' end + ' ('+isnull(ckey.cols,ikey.cols)+');' 
				 when i.index_id = 1 and i.is_primary_key = 0 then
					'create '+ case when i.is_unique = 1 then 'unique' else '' end+' clustered index '+quotename(i.name)+ ' on ' + schema_name(o.schema_id) + '.' + object_name(o.object_id) + ' ('+ckey.cols+')'
					+ case when i.has_filter = 1 then ' where ' + i.filter_definition else '' end + ';'
				 when i.type = 6 then
					'create nonclustered columnstore index ' + quotename(i.name) + ' on ' + schema_name(o.schema_id) + '.' + object_name(o.object_id) + ' ('+ikey.cols+') ;'
				 when i.index_id <> 1 then 
					'create '+case when i.is_unique = 1 then 'unique' else '' end+' nonclustered index '+quotename(i.name)+ ' on ' + schema_name(o.schema_id) + '.' + object_name(o.object_id) + ' ('+ckey.cols+')'+isnull(' include ('+ikey.cols+')','')
					+ case when i.has_filter = 1 then ' where ' + i.filter_definition else '' end + ';'
			 end
		FROM sys.indexes i join sys.objects o on i.object_id = o.object_id and (o.type = 'U' or o.type = 'V')
		LEFT JOIN sys.objects pk ON pk.parent_object_id = i.object_id AND pk.[type] = 'pk'
		LEFT JOIN sys.objects uk ON uk.parent_object_id = i.object_id AND uk.[type] = 'uq'
		OUTER APPLY (
				SELECT STUFF((SELECT ',' + case charindex(' ', c.name) when 0 then c.name else quotename(c.name) end + CASE is_descending_key WHEN 1 THEN ' desc' else '' END
				FROM sys.index_columns ic
					INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
				WHERE ic.index_id = i.index_id 
					AND ic.object_id = i.object_id
					AND ic.is_included_column = 0 --this column is not included
				ORDER BY ic.key_ordinal --order by the why it was entered
				FOR XML PATH('')),1,1,'')
		) ckey(cols)
		OUTER APPLY	(
				SELECT STUFF((SELECT ',' + case charindex(' ', c.name) when 0 then c.name else quotename(c.name) end
				FROM sys.index_columns ic
					INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
				WHERE ic.index_id = i.index_id
					AND ic.object_id = i.object_id
					AND ic.is_included_column = 1 --column is included
				ORDER BY ic.key_ordinal --order by way it was entered
				FOR XML PATH('')),1,1,'')
		) ikey(cols)
		WHERE	i.is_disabled = 0 --Index is not disabled
		and o.object_id = object_id(@objectname)
		--Order by 2;
	GO