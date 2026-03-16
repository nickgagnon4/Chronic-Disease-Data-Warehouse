-----------------------------------------
--	MGMT 6570 Data Warehouse Project
--  Nicholas Gagnon
--  December 8, 2025
-----------------------------------------

USE ChronicDisease
GO

-----------------------------------------
--  COLLECT: Staging Table
--  Drop, Create, and Load the ChronicDiseaseStaging table
-----------------------------------------

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ChronicDiseaseStaging]') AND type in (N'U'))
DROP TABLE [dbo].[ChronicDiseaseStaging]
GO

CREATE TABLE dbo.ChronicDiseaseStaging (
    YearStart               VARCHAR(20),
    YearEnd                 VARCHAR(20),
    LocationAbbr            VARCHAR(10),
    LocationDesc            VARCHAR(200),
    DataSource              VARCHAR(200),
    Topic                   VARCHAR(200),
    Question                VARCHAR(500),
    Response                VARCHAR(400),
    DataValueUnit           VARCHAR(50),
    DataValueType           VARCHAR(100),
    DataValue               VARCHAR(50),
    DataValueAlt            VARCHAR(50),
    DataValueFootnoteSymbol VARCHAR(10),
    DataValueFootnote       VARCHAR(500),
    LowConfidenceLimit      VARCHAR(50),
    HighConfidenceLimit     VARCHAR(50),
    StratificationCategory1 VARCHAR(100),
    Stratification1         VARCHAR(200),
    StratificationCategory2 VARCHAR(100),
    Stratification2         VARCHAR(200),
    StratificationCategory3 VARCHAR(100),
    Stratification3         VARCHAR(200),
    GeoLocation             VARCHAR(200),
    LocationID              VARCHAR(20),
    TopicID                 VARCHAR(20),
    QuestionID              VARCHAR(20),
    ResponseID              VARCHAR(20),
    DataValueTypeID         VARCHAR(20),
    StratificationCategoryID1 VARCHAR(20),
    StratificationID1       VARCHAR(20),
    StratificationCategoryID2 VARCHAR(20),
    StratificationID2       VARCHAR(20),
    StratificationCategoryID3 VARCHAR(20),
    StratificationID3       VARCHAR(20)
)

-- Load raw CSV into staging
BULK INSERT dbo.ChronicDiseaseStaging
FROM 'C:\Data\ChronicDiseaseProject\U.S._Chronic_Disease_Indicators.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    TABLOCK,
	ROWTERMINATOR = '0x0a'
)

-- Quick check
SELECT TOP 20 *
FROM dbo.ChronicDiseaseStaging

-----------------------------------------
--  COLLECT: Clean Table (ChronicDiseaseClean)
--  Apply rounding & data quality rules
-----------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ChronicDiseaseClean]') AND type = N'U')
DROP TABLE [dbo].[ChronicDiseaseClean];
GO

CREATE TABLE dbo.ChronicDiseaseClean (
    CleanID               INT IDENTITY(1,1) PRIMARY KEY,
    YearStart             INT,
    YearEnd               INT,
    LocationAbbr          VARCHAR(10),
    LocationDesc          VARCHAR(200),
    DataSource            VARCHAR(200),
    Topic                 VARCHAR(200),
    Question              VARCHAR(500),
    Response              VARCHAR(400),
    DataValueUnit         VARCHAR(50),
    DataValueType         VARCHAR(100),
    DataValue             DECIMAL(12,4),
    DataValueAlt          DECIMAL(12,4),
    LowConfidenceLimit    DECIMAL(12,4),
    HighConfidenceLimit   DECIMAL(12,4),
    StratificationCategory1 VARCHAR(100),
    Stratification1       VARCHAR(200),
    StratificationCategory2 VARCHAR(100),
    Stratification2       VARCHAR(200),
    StratificationCategory3 VARCHAR(100),
    Stratification3       VARCHAR(200),
    GeoLocation           VARCHAR(200)
)

INSERT INTO dbo.ChronicDiseaseClean (
    YearStart, YearEnd,
    LocationAbbr, LocationDesc,
    DataSource, Topic, Question, Response,
    DataValueUnit, DataValueType,
    DataValue, DataValueAlt,
    LowConfidenceLimit, HighConfidenceLimit,
    StratificationCategory1, Stratification1,
    StratificationCategory2, Stratification2,
    StratificationCategory3, Stratification3,
    GeoLocation
)
SELECT
    TRY_CONVERT(INT, YearStart)      AS YearStart,
    TRY_CONVERT(INT, YearEnd)        AS YearEnd,
    LTRIM(RTRIM(LocationAbbr))       AS LocationAbbr,
    LTRIM(RTRIM(LocationDesc))       AS LocationDesc,
    LTRIM(RTRIM(DataSource))         AS DataSource,
    LTRIM(RTRIM(Topic))              AS Topic,
    LTRIM(RTRIM(Question))           AS Question,
    LTRIM(RTRIM(Response))           AS Response,
    LTRIM(RTRIM(DataValueUnit))      AS DataValueUnit,
    LTRIM(RTRIM(DataValueType))      AS DataValueType,
    TRY_CONVERT(DECIMAL(12,4), DataValue)        AS DataValue,
    TRY_CONVERT(DECIMAL(12,4), DataValueAlt)     AS DataValueAlt,
    TRY_CONVERT(DECIMAL(12,4), LowConfidenceLimit)  AS LowConfidenceLimit,
    TRY_CONVERT(DECIMAL(12,4), HighConfidenceLimit) AS HighConfidenceLimit,
    LTRIM(RTRIM(StratificationCategory1)) AS StratificationCategory1,
    LTRIM(RTRIM(Stratification1))         AS Stratification1,
    LTRIM(RTRIM(StratificationCategory2)) AS StratificationCategory2,
    LTRIM(RTRIM(Stratification2))         AS Stratification2,
    LTRIM(RTRIM(StratificationCategory3)) AS StratificationCategory3,
    LTRIM(RTRIM(Stratification3))         AS Stratification3,
    LTRIM(RTRIM(GeoLocation))             AS GeoLocation
FROM dbo.ChronicDiseaseStaging
WHERE
    TRY_CONVERT(INT, YearStart) IS NOT NULL
    AND TRY_CONVERT(DECIMAL(12,4), DataValue) IS NOT NULL
    AND LocationAbbr IS NOT NULL
    AND LocationDesc IS NOT NULL;

-- Check
SELECT COUNT(*) AS CleanRowCount
FROM dbo.ChronicDiseaseClean

SELECT TOP 10 *
FROM dbo.ChronicDiseaseClean

-----------------------------------------
--  ORGANIZE: Drop existing DW tables
-----------------------------------------

IF OBJECT_ID(N'dbo.factChronic','U') IS NOT NULL
    DROP TABLE dbo.factChronic;
IF OBJECT_ID(N'dbo.dimStratification','U') IS NOT NULL
    DROP TABLE dbo.dimStratification;
IF OBJECT_ID(N'dbo.dimIndicator','U') IS NOT NULL
    DROP TABLE dbo.dimIndicator;
IF OBJECT_ID(N'dbo.dimYear','U') IS NOT NULL
    DROP TABLE dbo.dimYear;
IF OBJECT_ID(N'dbo.dimLocation','U') IS NOT NULL
    DROP TABLE dbo.dimLocation;

-----------------------------------------
--  Dimension: Location (region)
-----------------------------------------

CREATE TABLE dbo.dimLocation (
    LocationKey   INT IDENTITY(1,1)
        CONSTRAINT PK_dimLocation PRIMARY KEY CLUSTERED,
    LocationAbbr  VARCHAR(10),
    LocationDesc  VARCHAR(200)
);

INSERT INTO dbo.dimLocation (LocationAbbr, LocationDesc)
SELECT DISTINCT LocationAbbr, LocationDesc
FROM dbo.ChronicDiseaseClean;

SELECT TOP 10 * FROM dbo.dimLocation;

-----------------------------------------
--  Dimension: Year
-----------------------------------------
CREATE TABLE dbo.dimYear (
    YearKey   INT IDENTITY(1,1)
        CONSTRAINT PK_dimYear PRIMARY KEY CLUSTERED,
    YearStart INT,
    YearEnd   INT
);

INSERT INTO dbo.dimYear (YearStart, YearEnd)
SELECT DISTINCT YearStart, YearEnd
FROM dbo.ChronicDiseaseClean;

SELECT TOP 10 * FROM dbo.dimYear

-----------------------------------------
--  Dimension: Indicator (what is measured)
-----------------------------------------
CREATE TABLE dbo.dimIndicator (
    IndicatorKey   INT IDENTITY(1,1)
        CONSTRAINT PK_dimIndicator PRIMARY KEY CLUSTERED,
    Topic          VARCHAR(200),
    Question       VARCHAR(500),
    Response       VARCHAR(400),
    DataValueUnit  VARCHAR(50),
    DataValueType  VARCHAR(100)
);

INSERT INTO dbo.dimIndicator (
    Topic, Question, Response, DataValueUnit, DataValueType
)
SELECT DISTINCT
    Topic, Question, Response, DataValueUnit, DataValueType
FROM dbo.ChronicDiseaseClean;

SELECT TOP 10 * FROM dbo.dimIndicator

-----------------------------------------
--  Dimension: Stratification (demographics/other splits)
-----------------------------------------
CREATE TABLE dbo.dimStratification (
    StratificationKey       INT IDENTITY(1,1)
        CONSTRAINT PK_dimStratification PRIMARY KEY CLUSTERED,
    StratificationCategory1 VARCHAR(100),
    Stratification1         VARCHAR(200),
    StratificationCategory2 VARCHAR(100),
    Stratification2         VARCHAR(200),
    StratificationCategory3 VARCHAR(100),
    Stratification3         VARCHAR(200)
);

INSERT INTO dbo.dimStratification (
    StratificationCategory1, Stratification1,
    StratificationCategory2, Stratification2,
    StratificationCategory3, Stratification3
)
SELECT DISTINCT
    StratificationCategory1, Stratification1,
    StratificationCategory2, Stratification2,
    StratificationCategory3, Stratification3
FROM dbo.ChronicDiseaseClean;

SELECT TOP 10 * FROM dbo.dimStratification;

-----------------------------------------
--  Fact Table: factChronic
--  Measure: DataValue (rate / %)
-----------------------------------------
CREATE TABLE dbo.factChronic (
    ChronicFactKey      INT IDENTITY(1,1)
        CONSTRAINT PK_factChronic PRIMARY KEY CLUSTERED,
    LocationKey         INT NOT NULL,
    YearKey             INT NOT NULL,
    IndicatorKey        INT NOT NULL,
    StratificationKey   INT NOT NULL,
    DataValue           DECIMAL(12,4),
    DataValueAlt        DECIMAL(12,4),
    LowConfidenceLimit  DECIMAL(12,4),
    HighConfidenceLimit DECIMAL(12,4),
    CONSTRAINT FK_factChronic_dimLocation
        FOREIGN KEY (LocationKey) REFERENCES dbo.dimLocation(LocationKey),
    CONSTRAINT FK_factChronic_dimYear
        FOREIGN KEY (YearKey) REFERENCES dbo.dimYear(YearKey),
    CONSTRAINT FK_factChronic_dimIndicator
        FOREIGN KEY (IndicatorKey) REFERENCES dbo.dimIndicator(IndicatorKey),
    CONSTRAINT FK_factChronic_dimStratification
        FOREIGN KEY (StratificationKey) REFERENCES dbo.dimStratification(StratificationKey)
);

-----------------------------------------
--  Load factChronic from ChronicDiseaseClean
-----------------------------------------
INSERT INTO dbo.factChronic (
    LocationKey, YearKey, IndicatorKey, StratificationKey,
    DataValue, DataValueAlt,
    LowConfidenceLimit, HighConfidenceLimit
)
SELECT
    L.LocationKey,
    Y.YearKey,
    I.IndicatorKey,
    S.StratificationKey,
    C.DataValue,
    C.DataValueAlt,
    C.LowConfidenceLimit,
    C.HighConfidenceLimit
FROM dbo.ChronicDiseaseClean C
JOIN dbo.dimLocation L
    ON  L.LocationAbbr = C.LocationAbbr
   AND L.LocationDesc  = C.LocationDesc
JOIN dbo.dimYear Y
    ON  Y.YearStart = C.YearStart
   AND (Y.YearEnd = C.YearEnd OR Y.YearEnd IS NULL OR C.YearEnd IS NULL)
JOIN dbo.dimIndicator I
    ON  I.Topic         = C.Topic
   AND I.Question      = C.Question
   AND ISNULL(I.Response,'') = ISNULL(C.Response,'')
   AND I.DataValueUnit = C.DataValueUnit
   AND I.DataValueType = C.DataValueType
JOIN dbo.dimStratification S
    ON  ISNULL(S.StratificationCategory1,'') = ISNULL(C.StratificationCategory1,'')
   AND ISNULL(S.Stratification1,'')         = ISNULL(C.Stratification1,'')
   AND ISNULL(S.StratificationCategory2,'') = ISNULL(C.StratificationCategory2,'')
   AND ISNULL(S.Stratification2,'')         = ISNULL(C.Stratification2,'')
   AND ISNULL(S.StratificationCategory3,'') = ISNULL(C.StratificationCategory3,'')
   AND ISNULL(S.Stratification3,'')         = ISNULL(C.Stratification3,'');

-- Check row counts
SELECT COUNT(*) AS FactRowCount FROM dbo.factChronic;

SELECT TOP 10 *
FROM dbo.factChronic;

SELECT TOP 20
    F.ChronicFactKey,
    L.LocationAbbr, L.LocationDesc,
    Y.YearStart,
    I.Topic, I.Question, I.Response, I.DataValueUnit, I.DataValueType,
    S.StratificationCategory1, S.Stratification1,
    S.StratificationCategory2, S.Stratification2,
    S.StratificationCategory3, S.Stratification3,
    F.DataValue, F.LowConfidenceLimit, F.HighConfidenceLimit
FROM dbo.factChronic F
JOIN dbo.dimLocation L       ON F.LocationKey       = L.LocationKey
JOIN dbo.dimYear Y           ON F.YearKey           = Y.YearKey
JOIN dbo.dimIndicator I      ON F.IndicatorKey      = I.IndicatorKey
JOIN dbo.dimStratification S ON F.StratificationKey = S.StratificationKey;