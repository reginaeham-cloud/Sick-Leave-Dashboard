// ============================================================
// QUERY 0: FolderPath (Parameter)
// ============================================================
// Diesen Query ZUERST anlegen:
//   Neue Quelle → Leere Abfrage → Erweiterten Editor → einfügen
//   Dann Rechtsklick auf Query → "In Parameter konvertieren"
//   Typ: Text, Aktueller Wert: dein Ordnerpfad
//
// Beispiel: "C:\Users\DeinName\Documents\Sick-Leave-Dashboard\"
// Wichtig: Abschließenden Backslash \ am Ende nicht vergessen!
// ============================================================
let
    Quelle = "C:\DeinPfad\Sick-Leave-Dashboard\"
in
    Quelle


// ============================================================
// QUERY 1: SickLeave_Data
// Liest alle Land-CSVs aus dem Ordner (FolderPath)
// ============================================================
let
    Source      = Folder.Files(FolderPath),
    LandFiles   = Table.SelectRows(Source, each Text.StartsWith([Name], "Land")),
    AddContent  = Table.AddColumn(LandFiles, "Data", each
        Csv.Document([Content], [
            Delimiter  = ";",
            Columns    = 12,
            Encoding   = 65001,
            QuoteStyle = QuoteStyle.None
        ])
    ),
    Expanded    = Table.ExpandTableColumn(AddContent, "Data",
        {"Column1","Column2","Column3","Column4","Column5","Column6",
         "Column7","Column8","Column9","Column10","Column11","Column12"}
    ),
    NoHeaders   = Table.SelectRows(Expanded,
        each not ([Column1] = "Country " or [Column1] = "Country" or [Column1] = null)
    ),
    Renamed     = Table.RenameColumns(NoHeaders, {
        {"Column1",  "Country"},
        {"Column2",  "Region"},
        {"Column3",  "Area"},
        {"Column4",  "Dealership"},
        {"Column5",  "Year"},
        {"Column6",  "Period"},
        {"Column7",  "HC"},
        {"Column8",  "SickLeaveHours"},
        {"Column9",  "CareLeaveHours"},
        {"Column10", "DoctorAppointmentHours"},
        {"Column11", "Instances"},
        {"Column12", "Date"}
    }),
    TrimCountry = Table.TransformColumns(Renamed, {{"Country", Text.Trim}}),
    FillEmpties = Table.ReplaceValue(
        Table.ReplaceValue(
            Table.ReplaceValue(TrimCountry,
                "", "0", Replacer.ReplaceValue, {"DoctorAppointmentHours"}),
            "", "0", Replacer.ReplaceValue, {"Instances"}),
        "", "0", Replacer.ReplaceValue, {"CareLeaveHours"}
    ),
    Typed       = Table.TransformColumnTypes(FillEmpties, {
        {"Country",                type text},
        {"Region",                 type text},
        {"Area",                   type text},
        {"Dealership",             type text},
        {"Year",                   Int64.Type},
        {"Period",                 type text},
        {"HC",                     Int64.Type},
        {"SickLeaveHours",         type number},
        {"CareLeaveHours",         type number},
        {"DoctorAppointmentHours", type number},
        {"Instances",              type number},
        {"Date",                   type date}
    }, "de-DE"),
    AddTotalHours = Table.AddColumn(Typed, "TotalAbsentHours",
        each [SickLeaveHours] + [CareLeaveHours] + [DoctorAppointmentHours],
        type number
    ),
    Final       = Table.SelectColumns(AddTotalHours, {
        "Country","Region","Area","Dealership",
        "Year","Period","Date",
        "HC","SickLeaveHours","CareLeaveHours","DoctorAppointmentHours",
        "Instances","TotalAbsentHours"
    })
in
    Final


// ============================================================
// QUERY 2: TargetHours
// Liest Master_Target Hours.csv aus dem Ordner (FolderPath)
// ============================================================
let
    Source     = Folder.Files(FolderPath),
    FileRow    = Table.SelectRows(Source, each [Name] = "Master_Target Hours.csv"),
    FileContent= FileRow{0}[Content],
    Parsed     = Csv.Document(FileContent, [Delimiter=";", Encoding=65001, QuoteStyle=QuoteStyle.None]),
    Headers    = Table.PromoteHeaders(Parsed, [PromoteAllScalars=true]),
    Trimmed    = Table.TransformColumns(Headers, {{"Country ", Text.Trim}}),
    Renamed    = Table.RenameColumns(Trimmed, {{"Country ", "Country"}}),
    Typed      = Table.TransformColumnTypes(Renamed, {
        {"Country",             type text},
        {"Year",                Int64.Type},
        {"Period",              type text},
        {"Working Days",        Int64.Type},
        {"Daily Target Hours",  Int64.Type}
    }),
    AddPerHC   = Table.AddColumn(Typed, "TargetHoursPerHC",
        each [Working Days] * [Daily Target Hours], Int64.Type
    )
in
    AddPerHC


// ============================================================
// QUERY 3: Benchmark
// Liest Absent Days of Employee Benchmark.csv aus dem Ordner (FolderPath)
// ============================================================
let
    Source     = Folder.Files(FolderPath),
    FileRow    = Table.SelectRows(Source, each [Name] = "Absent Days of Employee Benchmark.csv"),
    FileContent= FileRow{0}[Content],
    Parsed     = Csv.Document(FileContent, [Delimiter=";", Encoding=65001, QuoteStyle=QuoteStyle.None]),
    Headers    = Table.PromoteHeaders(Parsed, [PromoteAllScalars=true]),
    Trimmed    = Table.TransformColumns(Headers, {{"Country", Text.Trim}}),
    Typed      = Table.TransformColumnTypes(Trimmed, {
        {"Country",          type text},
        {"Year",             Int64.Type},
        {"Country Average",  type number}
    }, "de-DE"),
    Renamed    = Table.RenameColumns(Typed, {{"Country Average", "BenchmarkDaysPerEmployee"}})
in
    Renamed


// ============================================================
// QUERY 4: DimDate
// Wird komplett in Power Query generiert – kein Dateizugriff nötig
// ============================================================
let
    StartDate  = #date(2024, 1, 1),
    EndDate    = #date(2027, 12, 31),
    DateList   = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1,0,0,0)),
    DateTable  = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    Typed      = Table.TransformColumnTypes(DateTable, {{"Date", type date}}),
    AddYear    = Table.AddColumn(Typed,    "Year",      each Date.Year([Date]),  Int64.Type),
    AddMonth   = Table.AddColumn(AddYear,  "Month",     each Date.Month([Date]), Int64.Type),
    AddMName   = Table.AddColumn(AddMonth, "MonthName", each Date.ToText([Date], "MMM", "de-DE"), type text),
    AddHalf    = Table.AddColumn(AddMName, "HalfYear",
        each if Date.Month([Date]) <= 6 then "H1" else "H2", type text),
    AddYearH   = Table.AddColumn(AddHalf,  "YearPeriod",
        each Text.From([Year]) & " " & [HalfYear], type text)
in
    AddYearH
