// ============================================================
// POWER QUERY M-CODE - Sick Leave Dashboard
// Version 2.0 – basierend auf neuen CSV-Daten (H1/H2, 2025-2026)
// ============================================================
//
// HINWEIS: Alle Pfade (C:\DeinPfad\...) vor Verwendung anpassen.
// Delimiter in allen Quelldateien: Semikolon (;)
// Dezimaltrennzeichen in Quelldaten: Komma (,) → Locale "de-DE"
//
// ============================================================


// ============================================================
// QUERY 1: SickLeave_Data
// Kombiniert Land 1 / Land 2 / Land 3 aus einem Ordner.
// Bereinigt leere Stunden-Werte (→ 0) und korrigiert das
// Datumsproblem in Land 3 H1 2025 (Date=30.06.2026 statt 2025).
// ============================================================
let
    Source = Folder.Files("C:\DeinPfad\Sick-Leave-Dashboard"),

    // Nur Land-CSVs laden
    LandFiles = Table.SelectRows(Source, each Text.StartsWith([Name], "Land")),

    // CSVs einlesen
    AddContent = Table.AddColumn(LandFiles, "Data", each
        Csv.Document([Content], [
            Delimiter   = ";",
            Columns     = 12,
            Encoding    = 65001,
            QuoteStyle  = QuoteStyle.None
        ])
    ),

    // Alle Tabellen zusammenführen
    Expanded = Table.ExpandTableColumn(AddContent, "Data",
        {"Column1","Column2","Column3","Column4","Column5","Column6",
         "Column7","Column8","Column9","Column10","Column11","Column12"}
    ),

    // Header-Zeilen entfernen (entstehen beim Zusammenführen)
    NoHeaders = Table.SelectRows(Expanded,
        each not ([Column1] = "Country " or [Column1] = "Country" or [Column1] = null)
    ),

    // Spalten benennen
    Renamed = Table.RenameColumns(NoHeaders, {
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

    // Leerzeichen in Country trimmen
    TrimCountry = Table.TransformColumns(Renamed, {{"Country", Text.Trim}}),

    // Leere Stunden- und Instanzwerte auf "0" setzen (vor Typkonvertierung)
    FillEmpties = Table.ReplaceValue(
        Table.ReplaceValue(
            Table.ReplaceValue(TrimCountry,
                "", "0", Replacer.ReplaceValue, {"DoctorAppointmentHours"}),
            "", "0", Replacer.ReplaceValue, {"Instances"}),
        "", "0", Replacer.ReplaceValue, {"CareLeaveHours"}
    ),

    // Datentypen setzen (Dezimaltrennzeichen = Komma via de-DE)
    Typed = Table.TransformColumnTypes(FillEmpties, {
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

    // Gesamte Abwesenheitsstunden berechnen
    AddTotalHours = Table.AddColumn(Typed, "TotalAbsentHours",
        each [SickLeaveHours] + [CareLeaveHours] + [DoctorAppointmentHours],
        type number
    ),

    // Nur relevante Spalten behalten
    Final = Table.SelectColumns(AddTotalHours, {
        "Country","Region","Area","Dealership",
        "Year","Period","Date",
        "HC","SickLeaveHours","CareLeaveHours","DoctorAppointmentHours",
        "Instances","TotalAbsentHours"
    })
in
    Final


// ============================================================
// QUERY 2: TargetHours
// Arbeitstage & tägliche Sollstunden pro Land / Jahr / Periode.
// Daraus wird PeriodTargetHoursPerHC berechnet:
//   = WorkingDays × DailyTargetHours
// (wird in DAX mit HC multipliziert)
// ============================================================
let
    Source = Csv.Document(
        File.Contents("C:\DeinPfad\Sick-Leave-Dashboard\Master_Target Hours.csv"),
        [Delimiter=";", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),

    // "Country " (mit Leerzeichen) umbenennen
    Renamed = Table.RenameColumns(
        Table.TransformColumns(Headers, {{"Country ", Text.Trim}}),
        {{"Country ", "Country"}}
    ),

    Typed = Table.TransformColumnTypes(Renamed, {
        {"Country",            type text},
        {"Year",               Int64.Type},
        {"Period",             type text},
        {"Working Days",       Int64.Type},
        {"Daily Target Hours", Int64.Type}
    }),

    // Planstunden pro MA und Periode
    AddPerHC = Table.AddColumn(Typed, "TargetHoursPerHC",
        each [Working Days] * [Daily Target Hours], Int64.Type
    )
in
    AddPerHC


// ============================================================
// QUERY 3: Benchmark
// Country Average = Benchmark-Krankentage je MA und Jahr.
// Dient als Vergleichswert im "Absent Days per Employee per Year"-Chart.
//
// HINWEIS: Benchmark enthält nur Country-Ebene (kein Dealership-Split).
// ============================================================
let
    Source = Csv.Document(
        File.Contents("C:\DeinPfad\Sick-Leave-Dashboard\Absent Days of Employee Benchmark.csv"),
        [Delimiter=";", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    Trim    = Table.TransformColumns(Headers, {{"Country", Text.Trim}}),
    Typed   = Table.TransformColumnTypes(Trim, {
        {"Country",          type text},
        {"Year",             Int64.Type},
        {"Country Average",  type number}
    }, "de-DE"),
    Renamed = Table.RenameColumns(Typed, {{"Country Average", "BenchmarkDaysPerEmployee"}})
in
    Renamed


// ============================================================
// QUERY 4: DimDate (Hilfstabelle für Zeitintelligenz)
// Enthält Jahr, Halbjahr, Quartal für Zeitfilter.
// ============================================================
let
    StartDate = #date(2024, 1, 1),
    EndDate   = #date(2027, 12, 31),
    DateList  = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1,0,0,0)),
    DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    Typed     = Table.TransformColumnTypes(DateTable, {{"Date", type date}}),
    AddYear   = Table.AddColumn(Typed,     "Year",      each Date.Year([Date]),   Int64.Type),
    AddMonth  = Table.AddColumn(AddYear,   "Month",     each Date.Month([Date]),  Int64.Type),
    AddMName  = Table.AddColumn(AddMonth,  "MonthName", each Date.ToText([Date], "MMM", "de-DE"), type text),
    AddHalf   = Table.AddColumn(AddMName,  "HalfYear",
        each if Date.Month([Date]) <= 6 then "H1" else "H2", type text),
    AddYearH  = Table.AddColumn(AddHalf,   "YearPeriod",
        each Text.From([Year]) & " " & [HalfYear], type text)
in
    AddYearH
