	IF OBJECT_ID('tempdb..#t') IS NOT NULL 
		DROP TABLE #t
	GO

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @x INT = 20

--SELECT 
--  [SchemaName] = ss.name
--, [TableName] = st.name
--, [IndexName] = s.name
--, [Statistics Last Updated] = STATS_DATE(s.id,s.indid)
--, [Row Count] = REPLACE(CONVERT(varchar(20), (CAST((s.rowcnt) AS money)), 1), '.00', '')
--, [Number Of Changes] = REPLACE(CONVERT(varchar(20), (CAST((s.rowmodctr) AS money)), 1), '.00', '')
--, [% Rows Changed] = CAST((CAST(s.rowmodctr AS DECIMAL(28,8))/CAST(s.rowcnt AS DECIMAL(28,2)) * 100.0) AS DECIMAL(28,2)) 
--, [Row Count INT] = s.rowcnt 
--, [Number Of Changes INT] = s.rowmodctr 
--INTO #t
--FROM sys.sysindexes s
--INNER JOIN sys.tables st ON st.[object_id] = s.[id]
--INNER JOIN sys.schemas ss ON ss.[schema_id] = st.[schema_id]
--WHERE s.id > 100
--AND s.indid > 0
--AND s.rowcnt >= 500
--ORDER BY SchemaName, TableName, IndexName 
---------------------------------------------
	SELECT 
		 [RID]						= IDENTITY(INT, 1, 1)
		,[DbName]					= DB_NAME()
		,[SchemaName]				= s.[name]
		,[TableName]				= t.[name]
		,[IndexName]				= i.[name]
		,[Statistics Last Updated]	= STATS_DATE(i.[id],i.[indid])
		,[Row Count txt]			= REPLACE(CONVERT(varchar(20), (CAST((i.[rowcnt]) AS money)), 1), '.00', '')
		,[Number Of Changes txt]	= REPLACE(CONVERT(varchar(20), (CAST((i.[rowmodctr]) AS money)), 1), '.00', '')
		,[% Rows Changed]			= CAST((CAST(i.[rowmodctr] AS DECIMAL(28,8))/CAST(i.[rowcnt] AS DECIMAL(28,2)) * 100.0) AS DECIMAL(28,2)) 
		,[WasAutoCreated]			= st.[auto_Created]  
		,[WasUserCreated]			= st.[user_created]  
		,[IsFiltered]				= st.[has_filter]
		,[FilterDefinition]			= st.[filter_definition] 
		,[Row Count INT]			= i.[rowcnt]
		,[Number Of Changes INT]	= i.[rowmodctr] 
	INTO #t
	FROM sys.sysindexes i
		JOIN sys.tables t ON t.[object_id] = i.[id] AND t.[object_id] > 1000
		JOIN sys.schemas s ON s.[schema_id] = t.[schema_id]
		LEFT JOIN sys.stats st ON st.[object_id] = i.[id] AND st.[stats_id] = i.[indid]
	WHERE i.[id] > 100
		AND i.[indid] > 0
		AND i.[rowcnt] >= 500
	ORDER BY [Number Of Changes INT] DESC --SchemaName, TableName, IndexName 
---------------------------------------------
SELECT TOP (@x)
[Sort] = 'noc',* 
FROM #t
ORDER BY [Number Of Changes INT] DESC;

/*
SELECT TOP (@x)
[Sort] = 'RC',* 
FROM #t
ORDER BY [Row Count INT] DESC;


SELECT TOP (@x)
[Sort] = '%RC',* 
FROM #t
ORDER BY [% Rows Changed]  DESC;


SELECT  [sch].[name] + '.' + [so].[name] AS [TableName] ,
        [si].[index_id] AS [Index ID] ,
        [ss].[name] AS [Statistic] ,
        STUFF(( SELECT  ', ' + [c].[name]
                FROM    [sys].[stats_columns] [sc]
                        JOIN [sys].[columns] [c]
                         ON [c].[column_id] = [sc].[column_id]
                            AND [c].[object_id] = [sc].[OBJECT_ID]
                WHERE   [sc].[object_id] = [ss].[object_id]
                        AND [sc].[stats_id] = [ss].[stats_id]
                ORDER BY [sc].[stats_column_id]
              FOR
                XML PATH('')
              ), 1, 2, '') AS [ColumnsInStatistic] ,
        [ss].[auto_Created] AS [WasAutoCreated] ,
        [ss].[user_created] AS [WasUserCreated] ,
        [ss].[has_filter] AS [IsFiltered] ,
        [ss].[filter_definition] AS [FilterDefinition] --,
        --[ss].[is_temporary] AS [IsTemporary] -- 2008 R2
FROM    [sys].[stats] [ss]
        JOIN [sys].[objects] AS [so] ON [ss].[object_id] = [so].[object_id]
        JOIN [sys].[schemas] AS [sch] ON [so].[schema_id] = [sch].[schema_id]
        LEFT OUTER JOIN [sys].[indexes] AS [si]
              ON [so].[object_id] = [si].[object_id]
                 AND [ss].[name] = [si].[name]
WHERE   [so].[object_id] = OBJECT_ID(N'dbo.mytablename')
ORDER BY [ss].[user_created] ,
        [ss].[auto_created] ,
        [ss].[has_filter];
GO
*/
SELECT * FROM #t
WHERE 1=1 
--AND [Statistics Last Updated] < DATEADD(MONTH ,-6 ,GETDATE())
AND [TableName] LIKE'%mytablename%'
ORDER BY 4 ASC --[Statistics Last Updated] ASC
--ORDER BY [Number Of Changes INT] DESC --[Statistics Last Updated] ASC

--UPDATE STATISTICS [myDB].[dbo].[mytablename] [myIX] WITH RESAMPLE;  -- "with fullscan"
	

/* 
https://www.simple-talk.com/sql/performance/sql-server-statistics-questions-we-were-too-shy-to-ask/
Can you create a set of statistics in SQL Server like you do in Oracle?

Oracle allows you to create custom statistics all the way down to creating your own histogram. SQL Server doesn’t give you that much control. 

However, you can create something in SQL Server that doesn’t exist in Oracle; filtered statistics. 
These are extremely useful when dealing with partitioned data or data that is wildly skewed due to wide ranging data or lots of nulls. 
Using AdventureWorks2012 as an example, I could create a set of statistics on multiple columns such as TaxAmt and CurrencyRateID 
in order to have a denser, more unique, value for the statistics than would be created by the optimizer on each of the columns separately. 
The code to do that looks like this:

CREATE STATISTICS TaxAmtFiltered

ON Sales.SalesOrderHeader (TaxAmt,CurrencyRateID)

WHERE TaxAmt > 1000 AND CurrencyRateID IS NOT NULL

WITH FULLSCAN;

This may help the optimizer to make better choices when creating the execution plan, but you’ll need to test it in any given setting. 
*/