set nocount on;

declare @singletable nvarchar(128) = null--'dbo.CLIENT_EPISODE_OASIS_ANSWERS'

declare @sqlstring nvarchar(max) = '
declare @FQtablename nvarchar(128) = ''@@@my_FQtablename'';
with cte as(
 select 
   ckey.cols as KeyColumns  
  ,ikey.cols as IncludeColumns  
  ,i.filter_definition as FilterDefn  
  ,[count(*)] = count(*)
 FROM sys.indexes i join sys.objects o on i.object_id = o.object_id and (o.type = ''U'' or o.type = ''V'')  
 LEFT JOIN sys.objects pk ON o.object_id = pk.object_id and pk.parent_object_id = i.object_id AND pk.[type] = ''pk''  
 LEFT JOIN sys.objects uk ON o.object_id = uk.object_id and uk.parent_object_id = i.object_id AND uk.[type] = ''uq''  
 left join sys.dm_db_index_usage_stats st on st.object_id = i.object_id  
  and st.index_id = i.index_id and st.database_id = db_id()  
 left join (select object_id, index_id, SUM(used_page_count) * 8 as IndexSize_KB   
      from sys.dm_db_partition_stats  
      group by object_id, index_id) pt on pt.object_id = i.object_id and pt.index_id = i.index_id  
 OUTER APPLY (  
   SELECT STUFF((SELECT '','' + c.name + CASE is_descending_key WHEN 1 THEN '' desc'' else '''' END  
   FROM sys.index_columns ic  
    INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id  
   WHERE ic.index_id = i.index_id   
    AND ic.object_id = i.object_id  
    AND ic.is_included_column = 0
   ORDER BY ic.key_ordinal 
   FOR XML PATH('''')),1,1,'''')  
 ) ckey(cols)  
 OUTER APPLY (  
   SELECT STUFF((SELECT '','' + c.name  
   FROM sys.index_columns ic  
    INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id  
   WHERE ic.index_id = i.index_id  
    AND ic.object_id = i.object_id  
    AND ic.is_included_column = 1  
   ORDER BY ic.key_ordinal 
   FOR XML PATH('''')),1,1,'''')  
 ) ikey(cols)  
 WHERE i.is_disabled = 0  
 and o.object_id = object_id(@FQtablename ,''U'')  
group by ckey.cols ,ikey.cols ,i.filter_definition
having COUNT(*) > 1
)
insert #output
 select 
   i.name as IndexName  
  ,st.User_Seeks, st.user_scans, st.user_updates  
  ,ckey.cols as KeyColumns  
  ,ikey.cols as IncludeColumns  
  ,i.filter_definition as FilterDefn  
 FROM sys.indexes i join sys.objects o on i.object_id = o.object_id and (o.type = ''U'' or o.type = ''V'')  
 LEFT JOIN sys.objects pk ON o.object_id = pk.object_id and pk.parent_object_id = i.object_id AND pk.[type] = ''pk''  
 LEFT JOIN sys.objects uk ON o.object_id = uk.object_id and uk.parent_object_id = i.object_id AND uk.[type] = ''uq''  
 left join sys.dm_db_index_usage_stats st on st.object_id = i.object_id  
  and st.index_id = i.index_id and st.database_id = db_id()  
 left join (select object_id, index_id, SUM(used_page_count) * 8 as IndexSize_KB   
      from sys.dm_db_partition_stats  
      group by object_id, index_id) pt on pt.object_id = i.object_id and pt.index_id = i.index_id  
 OUTER APPLY (  
   SELECT STUFF((SELECT '','' + c.name + CASE is_descending_key WHEN 1 THEN '' desc'' else '''' END  
   FROM sys.index_columns ic  
    INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id  
   WHERE ic.index_id = i.index_id   
    AND ic.object_id = i.object_id  
    AND ic.is_included_column = 0 
   ORDER BY ic.key_ordinal 
   FOR XML PATH('''')),1,1,'''')  
 ) ckey(cols)  
 OUTER APPLY (  
   SELECT STUFF((SELECT '','' + c.name  
   FROM sys.index_columns ic  
    INNER JOIN sys.all_columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id  
   WHERE ic.index_id = i.index_id  
    AND ic.object_id = i.object_id  
    AND ic.is_included_column = 1  
   ORDER BY ic.key_ordinal  
   FOR XML PATH('''')),1,1,'''')  
 ) ikey(cols)  
join cte on ckey.cols = cte.KeyColumns
and isnull(ikey.cols,'''') = isnull(cte.IncludeColumns ,'''')
and isnull(i.filter_definition,'''') = isnull(cte.FilterDefn,'''')
 WHERE i.is_disabled = 0 
 and o.object_id = object_id(@FQtablename ,''U'')
'   

if object_id('tempdb..#output') is not null 
begin drop table #output; end;
	
create table #output(IndexName varchar(128) ,User_Seeks int ,user_scans int ,user_updates int ,KeyColumns varchar(2000), IncludeColumns varchar(2000) ,FilterDefn varchar(2000));
		
declare @tablescope table(RID int identity(1,1) primary key ,FQ_tablename nvarchar(128));

insert @tablescope 
select convert(nvarchar(max),s.name) + '.' + convert(nvarchar(max),t.name) from sys.tables t join sys.schemas s on t.schema_id = s.schema_id 
where (@singletable is null or t.name = @singletable)
order by 1;

declare @start int = 1 ,@end int = (select MAX(rid) from @tablescope);

while @start <= @end
begin

declare @FQ_targettablename nvarchar(max) = (select FQ_tablename from @tablescope where RID = @start); 

declare @sqlexec nvarchar(max) = replace(@sqlstring,N'@@@my_FQtablename' ,@FQ_targettablename); 

--select @start, @FQ_targettablename ,@sqlstring;
exec sp_executesql @sqlexec ,N'@FQ_targettablename nvarchar(max)' ,@FQ_targettablename = @FQ_targettablename;

set @start += 1;


end

select * from #output
