--Value Density for Index Order.sql

begin
	set nocount on
	set transaction isolation level read uncommitted;

	declare 
	 @FQ_tablename varchar(128) = 'dbo.mytable'
	,@columnstring varchar(1000) = 'Paid, Epiid, WoundID, WoundHistID, WoundNumber, AnatSequence, AnatRoot, WoundDesc, OnsetDate, VisitDate, WorkerName, StageHistory, WATscore, WoundActive, OriginCevid, QuestGroupID, QuestGroupName, QuestGroupEffFrom, QuestGroupEffTo, wcq_summaryvisible, cwd_wcqid, Sequence, QuestCategory, Question, wcq_short, Answer, wca_order, WoundReasonType, WoundReason, ChangeInStatus, CareDetails, WoundAssessed, BaseAssess, LatestAssess, cwo_oid, cwo_effectivefrom, cwo_effectiveto, cwo_active, o_orderdate, ot_desc, o_desc, OrderVoided, OrderDeclined, PhotoDate, PhotoPath, RowNum, ColNum'	

	declare @columns table(rid int identity(1,1) ,columnname varchar(128) primary key nonclustered);

-- "dbo.fn_SplitString" is proprietary but can be commonly found. Its just a TSQL-based string splitter
	insert @columns select stringname from [myDB].dbo.fn_SplitString(@columnstring, ',');

	declare @seed int = 1, @seedmax int = (select COUNT(*) from @columns)
	declare @NewLineChar as char(2) = char(13) + char(10) 
	declare @sql nvarchar(max) = 'SELECT ' + @NewLineChar + ' [All] = COUNT(*) ' + @NewLineChar

	while @seed <= @seedmax
	begin

		select @sql = @sql + ',' + columnname + '= COUNT(DISTINCT ' + columnname + ')' + @NewLineChar
		from @columns where rid = @seed

		set @seed += 1;

	end

	set @sql = @sql + 'FROM ' + @FQ_tablename + ' with(nolock);'

	print @sql
	
	exec sp_executesql @sql;

end

select name +',' from sys.all_columns where object_id = object_id('dbo.mytable')
order by column_id asc

		DECLARE @RecCount DECIMAL(9,2) = (SELECT COUNT(*) FROM dbo.mytable)
		DECLARE @ValUnqCount DECIMAL(9,2) = (SELECT COUNT(DISTINCT [mycolumn]) FROM dbo.mytable)
		SELECT  @ValUnqCount / @RecCount
		
		--[pa_id]				1.000000000000
		--[pa_firstname]		0.085829891020
		--[pa_lastname]			0.342635800989
		--[pa_ssn]				0.662199884394
		--[pa_MedicareNum]		0.421946371172
		--[pa_medicaidnumber]	0.019166243726
		

	--DECLARE @All DECIMAL(19,2) = (
	--	SELECT 
	--	[All] = COUNT(*)
	--	FROM dbo.mytable
	--);



			