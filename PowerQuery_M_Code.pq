// ============================================================
// POWER QUERY M-CODE - Sick Leave Dashboard
// Alle Schritte im Power Query Editor einfügen
// ============================================================


// ============================================================
// QUERY 1: SickLeave_Data (Haupttabelle – alle 3 Länder kombiniert)
// ============================================================
let
    // Pfade anpassen: Ordner mit den 3 CSV-Dateien angeben
    Source = Folder.Files("C:\DeinPfad\Sick-Leave-Dashboard"),

    // Nur die Land-CSVs laden
    FilteredFiles = Table.SelectRows(Source, each Text.StartsWith([Name], "Land")),

    // Alle CSVs einlesen und zusammenführen
    AddContent = Table.AddColumn(FilteredFiles, "Data", each
        Csv.Document(
            [Content],
            [Delimiter = ";", Columns = 12, Encoding = 65001, QuoteStyle = QuoteStyle.None]
        )
    ),
    ExpandData = Table.ExpandTableColumn(AddContent, "Data",
        {"Column1","Column2","Column3","Column4","Column5","Column6",
         "Column7","Column8","Column9","Column10","Column11","Column12"}
    ),

    // Erste Zeile jeder Datei als Header entfernen (redundante Headerzeilen)
    RemoveHeaders = Table.SelectRows(ExpandData, each [Column1] <> "Country " and [Column1] <> "Country"),

    // Spalten umbenennen
    Renamed = Table.RenameColumns(RemoveHeaders, {
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

    // Nur relevante Spalten behalten
    SelectedCols = Table.SelectColumns(Renamed, {
        "Country","Region","Area","Dealership","Year","Period",
        "HC","SickLeaveHours","CareLeaveHours","DoctorAppointmentHours","Instances","Date"
    }),

    // Leerzeichen in Country-Spalte entfernen
    TrimCountry = Table.TransformColumns(SelectedCols, {{"Country", Text.Trim}}),

    // Datentypen setzen
    TypedTable = Table.TransformColumnTypes(TrimCountry, {
        {"Country",                 type text},
        {"Region",                  type text},
        {"Area",                    type text},
        {"Dealership",              type text},
        {"Year",                    Int64.Type},
        {"Period",                  type text},
        {"HC",                      Int64.Type},
        {"SickLeaveHours",          type number},
        {"CareLeaveHours",          type number},
        {"DoctorAppointmentHours",  type number},
        {"Instances",               type number},
        {"Date",                    type date}
    }, "de-DE"),

    // Leere Instanzen auf 0 setzen
    FillInstances = Table.ReplaceValue(TypedTable, null, 0, Replacer.ReplaceValue, {"Instances"}),

    // Total Absent Hours berechnen
    AddTotalHours = Table.AddColumn(FillInstances, "TotalAbsentHours",
        each [SickLeaveHours] + [CareLeaveHours] + [DoctorAppointmentHours],
        type number
    )

in
    AddTotalHours


// ============================================================
// QUERY 2: TargetHours (Arbeitstage & Stunden pro Land/Jahr/Period)
// ============================================================
let
    Source = Csv.Document(
        File.Contents("C:\DeinPfad\Sick-Leave-Dashboard\Master_Target Hours.csv"),
        [Delimiter=";", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    PromoteHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    TrimCols       = Table.TransformColumns(PromoteHeaders, {{"Country ", Text.Trim}}),
    Renamed        = Table.RenameColumns(TrimCols, {{"Country ", "Country"}}),
    Typed          = Table.TransformColumnTypes(Renamed, {
        {"Country",          type text},
        {"Year",             Int64.Type},
        {"Period",           type text},
        {"Working Days",     Int64.Type},
        {"Daily Target Hours", Int64.Type}
    }),
    // Planstunden pro Period = Arbeitstage × Tagesarbeitszeit
    AddTargetHours = Table.AddColumn(Typed, "PeriodTargetHours",
        each [Working Days] * [Daily Target Hours], Int64.Type
    )
in
    AddTargetHours


// ============================================================
// QUERY 3: Benchmark (Länder-Benchmark Krankentage je MA)
// ============================================================
let
    Source = Csv.Document(
        File.Contents("C:\DeinPfad\Sick-Leave-Dashboard\Absent Days of Employee Benchmark.csv"),
        [Delimiter=";", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    PromoteHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    TrimCols       = Table.TransformColumns(PromoteHeaders, {{"Country", Text.Trim}}),
    Typed          = Table.TransformColumnTypes(TrimCols, {
        {"Country",          type text},
        {"Year",             Int64.Type},
        {"Country Average",  type number}
    }, "de-DE"),
    Renamed        = Table.RenameColumns(Typed, {{"Country Average", "BenchmarkDaysPerEmployee"}})
in
    Renamed


// ============================================================
// QUERY 4: DimDate (Kalendertabelle für Zeitintelligenz)
// ============================================================
let
    StartDate = #date(2024, 1, 1),
    EndDate   = #date(2026, 12, 31),
    DateList  = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1,0,0,0)),
    DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(DateTable, {{"Date", type date}}),
    AddYear   = Table.AddColumn(Typed,   "Year",    each Date.Year([Date]),    Int64.Type),
    AddMonth  = Table.AddColumn(AddYear, "Month",   each Date.Month([Date]),   Int64.Type),
    AddMonthName = Table.AddColumn(AddMonth, "MonthName", each Date.ToText([Date], "MMM", "de-DE"), type text),
    AddQ      = Table.AddColumn(AddMonthName, "Quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddH      = Table.AddColumn(AddQ, "HalfYear",
        each if Date.Month([Date]) <= 6 then "H1" else "H2", type text),
    AddYearH  = Table.AddColumn(AddH, "YearPeriod",
        each Text.From([Year]) & " " & [HalfYear], type text)
in
    AddYearH
