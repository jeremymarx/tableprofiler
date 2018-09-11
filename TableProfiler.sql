
/*
Name: Table Profiler
Author: Jeremy Marx
Purpose: Generates profile report for each column of the specified table, describing the column quantitatively and descriptively, as well as looking at frequent values and other essentials.

Todo:

- Add column default values.
- Add computed column calculations.
- Build new output formats (Expert vs Simplified, etc).
- Separate table properties from column properties. Separate dataset.
- Add new output geared toward copy-paste into Kimball MDW Toolkit Datamodel spreadsheet.
- Make collation-aware.
- Add filters, top x, etc.

*/
USE AdventureWorks2017;
GO

DECLARE @Schema NVARCHAR(100) = 'Sales'
      , @Table NVARCHAR(100) = 'SalesOrderDetail'
	  , @Debug BIT = 0;

DECLARE @nl VARCHAR(2) = CHAR(13) + CHAR(10);

-- Build DataTypes Reference table
-- Derived from http://www.connectionstrings.com/sql-server-data-types-reference/
IF OBJECT_ID('tempdb.dbo.#DataTypes', 'U') IS NOT NULL
    DROP TABLE #DataTypes;
CREATE TABLE #DataTypes
(
    [DataTypeId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
	[DataType] NVARCHAR(40) NOT NULL,
	[Type] NVARCHAR(20) NOT NULL,
	[Subtype] NVARCHAR(20) NOT NULL,
	[Min] NVARCHAR(40) NULL,
	[Max] NVARCHAR(40) NULL,
	[Storage] NVARCHAR(400) NULL,
	[FirstVersion] TINYINT NOT NULL DEFAULT(0)
);
INSERT INTO [#DataTypes]
        ([DataType], [Type], [Subtype], [Min], [Max], [Storage], [FirstVersion])
VALUES (N'BIGINT', N'NUMERIC', N'EXACT', N'-9223372036854775808', N'9223372036854775807', N'8 bytes', 0),
	   (N'INT', N'NUMERIC', N'EXACT', N'-2147483648', N'2147483647', N'4 bytes', 0),
	   (N'SMALLINT', N'NUMERIC', N'EXACT', N'-32768', N'32767', N'2 bytes', 0),
	   (N'TINYINT', N'NUMERIC', N'EXACT', N'0', N'255', N'1 bytes', 0),
	   (N'BIT', N'NUMERIC', N'EXACT', N'0', N'1', N'1 to 8 bit columns in the same table requires a total of 1 byte, 9 to 16 bits = 2 bytes, etc...', 0),
	   (N'DECIMAL', N'NUMERIC', N'EXACT', N'-10^38+1', N'10^38–1', N'Precision 1-9 = 5 bytes, precision 10-19 = 9 bytes, precision 20-28 = 13 bytes, precision 29-38 = 17 bytes', 0),
	   (N'NUMERIC', N'NUMERIC', N'EXACT', N'-10^38+1', N'10^38–1', N'Precision 1-9 = 5 bytes, precision 10-19 = 9 bytes, precision 20-28 = 13 bytes, precision 29-38 = 17 bytes', 0),
	   (N'MONEY', N'NUMERIC', N'EXACT', N'-922337203685477.5808', N'922337203685477.5807', N'8 bytes', 0),
	   (N'SMALLMONEY', N'NUMERIC', N'EXACT', N'-214748.3648', N'214748.3647', N'4 bytes', 0),
	   (N'FLOAT', N'NUMERIC', N'APPROX', N'-1.79E + 308', N'1.79E + 308', N'4 bytes when precision is less than 25 and 8 bytes when precision is 25 through 53', 0),
	   (N'REAL', N'NUMERIC', N'APPROX', N'-3.40E + 38', N'3.40E + 38', N'4 bytes', 0),
	   (N'DATETIME', N'DATETIME', N'', N'1753-01-01 00:00:00.000', N'2958465.99999997', N'8 bytes', 0),
	   (N'SMALLDATETIME', N'DATETIME', N'', N'1', N'65537.9993055556', N'4 bytes', 0),
	   (N'DATE', N'DATETIME', N'', N'0001-01-01', N'2958465', N'3 bytes', 10),
	   (N'TIME', N'DATETIME', N'', N'0', N'1', N'time(0-2) = 3 bytes, time(3-4) = 4 bytes, time(5-7) = 5 bytes', 10),
	   (N'DATETIME2', N'DATETIME', N'', N'0001-01-01 00:00:00.0000000', N'2958466', N'Precision 1-2 = 6 bytes precision 3-4 = 7 bytes precision 5-7 = 8 bytes', 10),
	   (N'DATETIMEOFFSET', N'DATETIME', N'', N'0001-01-01 00:00:00.0000000 -14:00', N'9999-12-31 23:59:59.9999999 +14:00', N'Presicion 1-2 = 8 bytes precision 3-4 = 9 bytes precision 5-7 = 10 bytes', 10),
	   (N'CHAR', N'STRING', N'ANSI', N'0 chars', N'8000 chars', N'Defined width', 0),
	   (N'VARCHAR', N'STRING', N'ANSI', N'0 chars', N'8000 chars', N'2 bytes + number of chars', 0),
	   (N'VARCHAR(MAX)', N'STRING', N'ANSI', N'0 chars', N'2^31 chars', N'2 bytes + number of chars', 9),
	   (N'TEXT', N'STRING', N'ANSI', N'0 chars', N'2,147,483,647 chars', N'4 bytes + number of chars', 0),
	   (N'NCHAR', N'STRING', N'UNICODE', N'0 chars', N'4000 chars', N'Defined width x 2', 0),
	   (N'NVARCHAR', N'STRING', N'UNICODE', N'0 chars', N'4000 chars', N'', 0),
	   (N'NVARCHAR(MAX)', N'STRING', N'UNICODE', N'0 chars', N'2^30 chars', N'', 9),
	   (N'NTEXT', N'STRING', N'UNICODE', N'0 chars', N'1,073,741,823 chars', N'', 0),
	   (N'BINARY', N'BINARY', N'', N'0 bytes', N'8000 bytes', N'', 0),
	   (N'VARBINARY', N'BINARY', N'', N'0 bytes', N'8000 bytes', N'', 0),
	   (N'VARBINARY(MAX)', N'BINARY', N'', N'0 bytes', N'2^31 bytes', N'', 9),
	   (N'IMAGE', N'BINARY', N'', N'0 bytes', N'2,147,483,647 bytes', N'', 0),
	   (N'SQL_VARIANT', N'OTHER', N'', N'', N'', N'', 0),
	   (N'TIMESTAMP', N'OTHER', N'', N'', N'', N'8 bytes', 0),
	   (N'UNIQUEIDENTIFIER', N'OTHER', N'', N'', N'', N'16 bytes', 0),
	   (N'XML', N'OTHER', N'', N'', N'', N'', 9),
	   (N'CURSOR', N'OTHER', N'', N'', N'', N'', 0),
	   (N'TABLE', N'OTHER', N'', N'', N'', N'', 0);


-- Build ColumnProfile table
IF OBJECT_ID('tempdb.dbo.#ColumnProfile', 'U') IS NOT NULL
    DROP TABLE #ColumnProfile;

CREATE TABLE #ColumnProfile
(
    [ProfileId] INT IDENTITY(1,1) NOT NULL,
	[TableId] INT NOT NULL,
	[SchemaId] INT NOT NULL,
	[ColumnId] INT NOT NULL,
	[Table] sysname NOT NULL,
	[Schema] NVARCHAR(128) NOT NULL,
	[Column] sysname NOT NULL,
	[Type] NVARCHAR(20) NOT NULL,
	[SubType] NVARCHAR(20) NOT NULL,
	[DataType] sysname NULL,
	[TypedSize] INT NULL, -- max_length/bytesize
	[TypedPrecision] INT NULL,
	[TypedScale] INT NULL,
	[Collation] NVARCHAR(100) NULL,
	[IsPK] BIT NULL,
	[IsUniqueConstrained] BIT NULL,
	[IsComputed] BIT NULL,
	[IsIdentity] BIT NULL,
	[IsNullable] BIT NULL,
	[ValuesCount] INT,
	[ValuesCardinality] INT,
	[ValuesSelectivity] AS ([ValuesCardinality]*1.0)/NULLIF([ValuesCount],0),
	[ValuesNULLCount] INT,
	[ValuesMin] NVARCHAR(MAX) NULL,
	[ValuesMax] NVARCHAR(MAX) NULL,
	[ValuesLengthMin] INT NULL,
	[ValuesLengthMax] INT NULL,
	[ValuesLengthAvg] INT NULL,
	[ValuesFreqTop1] NVARCHAR(MAX) NULL,
	[ValuesFreqTop1Count] INT NULL,
	[ValuesFreqTop2] NVARCHAR(MAX) NULL,
	[ValuesFreqTop2Count] INT NULL,
	[ValuesFreqTop3] NVARCHAR(MAX) NULL,
	[ValuesFreqTop3Count] INT NULL,
	[SizeOnDisk] INT NULL,
	[IsUnique] NVARCHAR(100) NULL,
 CONSTRAINT [PK_ColumnProfile] PRIMARY KEY CLUSTERED 
(
	[Schema] ASC,
	[Table] ASC,
	[Column] ASC
));

-- Build other tables
IF OBJECT_ID('tempdb.dbo.#Counts', 'U') IS NOT NULL
    DROP TABLE #Counts;
CREATE TABLE #Counts
(
    [Value] NVARCHAR(100),
    [Rowcount] INT,
    [Row] TINYINT
);

-- Get standard metadata concerning each column.
INSERT INTO [#ColumnProfile]
        ([TableId] 
	   , [SchemaId]
	   , [ColumnId]
	   , [Table]
       , [Schema]
       , [Column]
	   , [Type]
	   , [SubType]
       , [DataType]
       , [TypedSize]
       , [TypedPrecision]
       , [TypedScale]
       , [Collation]
       , [IsComputed]
	   , [IsIdentity]
       , [IsNullable])
SELECT	  t.[object_id]
		, t.[schema_id]
		, c.[column_id]
		, t.[name]
		, OBJECT_SCHEMA_NAME([t].[object_id])
		, c.[name]
		, dt.[Type]
		, dt.[Subtype]
		, ty.[name]
		, c.[max_length]
		, c.[precision]
		, c.[scale]
		, COALESCE(c.[collation_name], '')
		, COALESCE(c.[is_computed], '')
		, COALESCE(c.[is_identity], '')
		, COALESCE(c.[is_nullable], '')
		--, *
FROM    [sys].[tables] AS [t]
        INNER JOIN [sys].[columns] AS [c]
            ON [t].[object_id] = [c].[object_id]
        INNER JOIN [sys].[types] AS [ty]
            ON [c].[user_type_id] = [ty].[user_type_id]
	    INNER JOIN [#DataTypes] AS [dt]
		    ON	 [ty].[name] = [dt].[DataType]
WHERE   [t].[name] = @Table AND
        OBJECT_SCHEMA_NAME([t].[object_id]) = @Schema;

-- Get index-based metadata
UPDATE	#ColumnProfile
SET		[IsPK] = [i].[is_primary_key]
	  , [IsUniqueConstrained] = [i].[is_unique_constraint] | [i].[is_primary_key]
FROM    [#ColumnProfile] AS [cp]
		INNER JOIN 
		sys.[indexes] AS [i]
			ON	cp.[TableId] = i.[object_id]
		INNER JOIN 
		sys.[index_columns] AS [ic]
			ON	[i].[index_id] = [ic].[index_id] AND
				[i].[object_id] = [ic].[object_id] AND
                [cp].[ColumnId] = [ic].[column_id];

UPDATE  [#ColumnProfile]
SET     [IsPK] = COALESCE([IsPK], 0)
      , [IsUniqueConstrained] = COALESCE([IsUniqueConstrained], 0);

-- Loop Through Each Column
DECLARE   @Columns INT = 1,
		@Column INT = 1,
		@ColumnName sysname,
		@DataType NVARCHAR(40),
		@Type NVARCHAR(20),
		@Subtype NVARCHAR(20),
		@SQL NVARCHAR(MAX);

SELECT  @Columns = MAX([cp].[ColumnId])
FROM    [#ColumnProfile] AS [cp]

IF (@Debug = 1) PRINT 'Looping through ' + CAST(@Columns AS VARCHAR(8)) + ' columns.';


WHILE (@Column <= @Columns)
BEGIN

	-- Assign run values.
	SELECT @ColumnName = [cp].[Column],
		   @DataType = dt.[DataType],
		   @Type = dt.[Type],
		   @Subtype = dt.[Subtype]
	FROM   [#ColumnProfile] AS [cp]
		   INNER JOIN 
	       [#DataTypes] AS [dt]
			 ON	[cp].[DataType] = [dt].[DataType]
	WHERE	[cp].[ColumnId] = @Column

    IF (@Debug = 1) PRINT '----------' + @nl + 'Processing [' + @ColumnName + '] column.';

	-- Get column counts.
    SELECT @SQL = REPLACE(REPLACE(REPLACE(
		  N'  
			 ; WITH [s1] AS
			 (
				SELECT ''@Column'' AS [Column],
					   [ValuesCount] = COUNT(*), 
					   COUNT(DISTINCT [@Column]) AS [ValuesCardinality], 
					   [ValuesNULLCount] = SUM(CASE WHEN [@Column] IS NULL THEN 1 ELSE 0 END),
					   [ValuesMin] = MIN([@Column]),
					   [ValuesMax] = MAX([@Column]),
					   [ValuesLengthMin] = MIN(LEN([@Column])),
					   [ValuesLengthAvg] = AVG(LEN([@Column])),
					   [ValuesLengthMax] = MAX(LEN([@Column])) 
				FROM    [@Schema].[@Table] AS [o]
			 )
			 UPDATE [cp]
			 SET [ValuesCount] = [s1].[ValuesCount], 
				 [ValuesCardinality] = [s1].[ValuesCardinality],
				 [ValuesNULLCount] = [s1].[ValuesNULLCount],
				 [ValuesMin] = [s1].[ValuesMin],
				 [ValuesMax] = [s1].[ValuesMax],
				 [ValuesLengthMin] = [s1].[ValuesLengthMin],
				 [ValuesLengthAvg] = [s1].[ValuesLengthAvg],
				 [ValuesLengthMax] = [s1].[ValuesLengthMax]
			 FROM	[#ColumnProfile] AS [cp]
					INNER JOIN 
					[s1] ON [cp].[Column] = [s1].[Column];',
					'@Column', @ColumnName), '@Table', @Table), '@Schema', @Schema);
    IF (@DataType NOT IN (N'text', N'ntext', N'image'))
	   EXEC (@SQL);


	-- Get most frequent values
	SELECT @SQL = REPLACE(REPLACE(REPLACE(
				N'  WITH    [s1]
						    AS (SELECT    [@column] AS [Value]
										, COUNT(*) AS [Rowcount]
										, ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS [Row]
							   FROM      [@schema].[@table]
							   WHERE     [@column] IS NOT NULL
							   GROUP BY  [@column]
				    )
					   INSERT INTO #Counts
					   SELECT [Value]
							, [Rowcount]
							, [Row]
					   FROM   [s1]
					   WHERE  [Row] <= 3;',
				'@Column', @ColumnName), '@Table', @Table), '@Schema', @Schema);
    
    IF (@DataType NOT IN (N'text', N'ntext', N'image'))
	   EXEC (@SQL);

	   UPDATE	 [#ColumnProfile]
	   SET	 [ValuesFreqTop1] = c.[Value],
			 [ValuesFreqTop1Count] = c.[Rowcount]
	   FROM	 [#ColumnProfile] AS [cp]
			 INNER JOIN [#Counts] AS [c]
				ON  cp.[ColumnId] = @Column AND
				    c.[Row] = 1;

	   UPDATE	 [#ColumnProfile]
	   SET	 [ValuesFreqTop2] = c.[Value],
			 [ValuesFreqTop2Count] = c.[Rowcount]
	   FROM	 [#ColumnProfile] AS [cp]
			 INNER JOIN [#Counts] AS [c]
				ON  cp.[ColumnId] = @Column AND
				    c.[Row] = 2;

	   UPDATE	 [#ColumnProfile]
	   SET	 [ValuesFreqTop3] = c.[Value],
			 [ValuesFreqTop3Count] = c.[Rowcount]
	   FROM	 [#ColumnProfile] AS [cp]
			 INNER JOIN [#Counts] AS [c]
				ON  cp.[ColumnId] = @Column AND
				    c.[Row] = 3;


	--IF @Type =	 'Numeric'
	--BEGIN

	--END
	--ELSE IF @Type = 'Datetime'
 --   BEGIN
        
 --   END
	--ELSE IF @Type = 'String'
 --   BEGIN
        
 --   END
	--ELSE IF @Type = 'Binary'
 --   BEGIN
        
 --   END
	--ELSE IF @Type = 'Other'
 --   BEGIN
        
 --   END

	-- Cleanup
	TRUNCATE TABLE [#Counts];

	SET @Column += 1;
END

IF (@Debug = 1) PRINT 'Column processing complete.';



SELECT  [cp].[Table]
      , [cp].[Column]
      , [cp].[DataType]
      , [cp].[TypedSize]
      , [cp].[TypedPrecision]
      , [cp].[TypedScale]
      , [cp].[IsNullable]
      , [cp].[Column]
      , [cp].[ValuesCount]
      , [cp].[ValuesCardinality]
      , [cp].[ValuesSelectivity]
      , [cp].[ValuesNULLCount]
      , [cp].[ValuesMin]
      , [cp].[ValuesMax]
      , [cp].[Column]
      , [cp].[ValuesFreqTop1]
      , [cp].[ValuesFreqTop1Count]
      , [cp].[ValuesFreqTop2]
      , [cp].[ValuesFreqTop2Count]
      , [cp].[ValuesFreqTop3]
      , [cp].[ValuesFreqTop3Count]
      , [cp].[Column]
	  , [cp].[ValuesLengthMin]
      , [cp].[ValuesLengthAvg]
      , [cp].[ValuesLengthMax]
      , [cp].[IsPK]
      , [cp].[IsUniqueConstrained]
      , [cp].[IsComputed]
      , [cp].[IsIdentity]
FROM    [#ColumnProfile] AS [cp];
