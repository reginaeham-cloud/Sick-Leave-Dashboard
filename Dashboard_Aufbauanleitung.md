# Sick Leave Dashboard – Power BI Aufbauanleitung
Version 2.0 | Stand: Juni 2026

---

## 1. Datenmodell

### Tabellen

| Tabelle | Quelle | Beschreibung |
|---------|--------|--------------|
| `SickLeave_Data` | Land 1/2/3.csv | Faktentabelle – Abwesenheitsstunden je Dealership, Halbjahr |
| `TargetHours` | Master_Target Hours.csv | Planstunden – Arbeitstage & Tagesarbeitszeit je Land/Jahr/Periode |
| `Benchmark` | Absent Days of Employee Benchmark.csv | Benchmark-Krankentage je MA auf Länderebene |
| `DimDate` | Power Query generiert | Kalender-Hilfstabelle für Zeitintelligenz |

### Beziehungen (Sternschema)

```
SickLeave_Data  →  TargetHours
  Country            Country
  Year          n:1  Year
  Period             Period

SickLeave_Data  →  Benchmark
  Country       n:1  Country
  Year               Year

SickLeave_Data  →  DimDate
  Date          n:1  Date
```

Alle Beziehungen: **aktiv**, **einfache Filterrichtung** (TargetHours/Benchmark → SickLeave_Data).

> **Bekannte Limitation:** Da kein separater Teilzeit-korrigierter Headcount (TC) in den
> Quelldaten vorhanden ist, wird **TC = HC** angenommen. Dies gilt insbesondere für den
> Bradford Factor. Bei hohem Teilzeitanteil kann der Bradford Factor leicht unterschätzt
> werden, da Teilzeitkräfte weniger Planstunden haben.

---

## 2. Daten laden (Power Query)

1. Power BI Desktop → **Daten abrufen → Ordner**
2. Ordner mit den drei Land-CSVs auswählen
3. Im **Erweiterten Editor** die Queries aus `PowerQuery_M_Code.pq` einfügen:
   - `SickLeave_Data` (kombiniert alle Land-CSVs automatisch)
   - `TargetHours`
   - `Benchmark`
   - `DimDate`
4. **Pfad anpassen:** Alle Vorkommen von `C:\DeinPfad\Sick-Leave-Dashboard` ersetzen
5. Schließen & Anwenden

---

## 3. Datenmodell konfigurieren

1. **Modellansicht** öffnen
2. Beziehungen gemäß Diagramm oben ziehen
3. Sternschema prüfen: `SickLeave_Data` in der Mitte
4. Neue Tabelle für Measures anlegen:
   ```
   Modellierung → Neue Tabelle → Measures = {}
   ```
5. Alle Measures aus `DAX_Measures.dax` als **Neues Measure** in diese Tabelle einfügen

---

## 4. KPI-Definitionen

### Sick Leave (%)
```
Sick Leave (%) = TotalAbsentHours / (HC × WorkingDays × DailyTargetHours)
```
- Zähler: Sick Leave + Care Leave + Doctor Appointment Hours
- Nenner: Planstunden = HC × Arbeitstage × Tagesarbeitszeit (aus TargetHours)
- Anzeige: Prozent mit 2 Nachkommastellen
- Vergleich: Differenz in Prozentpunkten (pp) zum Vorjahr

### Absent Days per Employee
```
Absent Days per Employee = TotalAbsentHours / (HC × DailyTargetHours)
```
- Alle drei Abwesenheitsarten
- Ergebnis in Arbeitstagen

### Missing HC / Day
```
Missing HC / Day = TotalAbsentHours / (WorkingDays × DailyTargetHours)
```
- Entspricht der Anzahl fehlender Vollzeitstellen (FTE) je Arbeitstag
- Basiert auf Planstunden-Basis (nicht HC-Basis) → leichter Methodenwechsel beabsichtigt

### Bradford Factor (Ø)
```
Bradford Factor = (Instances / HC)² × (TotalAbsentHours / DailyTargetHours / HC)
```
- Berechnung **je Dealership**, dann **Durchschnitt (Ø)** über den Filterkontext
- **TC = HC** (Limitation, s. oben)
- Ampelwerte: < 50 = Grün, 50–100 = Gelb, > 100 = Rot

---

## 5. Dashboard-Layout (2 Report-Seiten)

### Seite 1: KPI-Übersicht

```
┌──────────────────────────────────────────────────────────────────────┐
│  FILTER-ZEILE (Dropdowns):                                           │
│  Business Area  │  Year  │  Period                                   │
├────────────┬────────────┬────────────┬──────────────────────────────┤
│ KPI-Card   │ KPI-Card   │ KPI-Card   │                              │
│            │            │            │  Missing HC / Day            │
│ Sick Leave │ Absent Days│ Missing HC │  Development                 │
│    (%)     │ per Employee│  / Day    │                              │
│   5,57%    │   14,03    │   48,92    │  Gruppiertes Balkendiagramm  │
│ ▼ -1,3pp   │ ▼ 0.0 vs.PY│▼ -10.0 vs.│  X-Achse: Year               │
│   vs. PY   │            │     PY     │  Orange Balken: Avg HC       │
│            │            │            │  Grauer Balken: Missing HC/D │
├────────────┴────────────┴────────────┤  Datenbeschriftungen an      │
│  Absent Days per Employee per Year   │  Balkenenende                │
│                                      │                              │
│  Horizontales Balkendiagramm         │                              │
│  Balken 1 (orange): Absent Days/MA   │                              │
│  Balken 2 (hellorange): Country Avg  │                              │
│  Balken 3 (grau): Ø Region           │                              │
└──────────────────────────────────────┴──────────────────────────────┘
```

**Visual-Konfiguration Seite 1:**

| Visual | Typ | Felder |
|--------|-----|--------|
| Sick Leave (%) | KPI-Card | Wert: `Sick Leave (%)`, Untertitel: `Sick Leave (%) vs PY Label` |
| Absent Days/Employee | KPI-Card | Wert: `Absent Days per Employee`, Untertitel: `Absent Days per Employee vs PY Label` |
| Missing HC / Day | KPI-Card | Wert: `Missing HC per Day`, Untertitel: `Missing HC per Day vs PY Label` |
| Missing HC/Day Development | Gruppierter Balken | X: Year, Werte: `Average HC` + `Missing HC per Day`, Legende: Measurename |
| Absent Days per Year | Horizontaler Balken | Y: Measurename, X: `Absent Days per Employee` + `Benchmark Days per Employee` + `Avg Region Days per Employee` |

**Bedingte Formatierung KPI-Cards:**
- Wert grün = besser als Vorjahr (negativer Δ)
- Wert rot = schlechter als Vorjahr (positiver Δ)
- Pfeile: ▼ grün (Verbesserung), ▲ rot (Verschlechterung)

---

### Seite 2: Bradford Factor & Sick Leave Matrix

```
┌──────────────────────────────────────────────────────────────────────┐
│  FILTER-ZEILE (Dropdowns):                                           │
│  Business Area  │  Year  │  Period  │  [Legende: Ampelwerte]        │
├──────────────────────────────────────────────────────────────────────┤
│  Matrix-Tabelle: Bradford Factor                                     │
│                                                                      │
│  Zeile 1: Business Area (aufklappbar)                                │
│  Zeile 2: Region (aufklappbar)                                       │
│  Zeile 3: Country                                                    │
│  Zeile 4: Dealership                                                 │
│                                                                      │
│  Spalten: Sum of HC | Sick Leave (%) | Bradford Factor (Ø)           │
│                                                                      │
│  Bedingte Formatierung:                                              │
│  - Sick Leave (%): Grün < 3% | Gelb 3–10% | Rot > 10%              │
│  - Bradford Factor (Ø): Grün < 50 | Gelb 50–100 | Rot > 100         │
└──────────────────────────────────────────────────────────────────────┘
```

**Matrix-Konfiguration:**

| Einstellung | Wert |
|-------------|------|
| Zeilen | Area → Region → Country → Dealership |
| Werte | `Total HC`, `Sick Leave (%)`, `Bradford Factor (Ø)` |
| Zeilensummen | Aktiviert (Gesamtzeile unten) |
| Teilergebnisse | Aktiviert auf allen Ebenen |

**Bedingte Formatierung (Hintergrundfarbe per Measure):**

Sick Leave (%) → Regeln:
- Wenn Wert < 0,03 → Hintergrund `#00B050` (Grün), Schrift `#FFFFFF`
- Wenn Wert ≥ 0,03 und ≤ 0,10 → Hintergrund `#FFC000` (Gelb), Schrift `#000000`
- Wenn Wert > 0,10 → Hintergrund `#FF0000` (Rot), Schrift `#FFFFFF`

Bradford Factor (Ø) → Regeln:
- Wenn Wert < 50 → kein Hintergrund (weiß)
- Wenn Wert ≥ 50 und ≤ 100 → Hintergrund `#FFC000` (Gelb)
- Wenn Wert > 100 → Hintergrund `#FF0000` (Rot), Schrift `#FFFFFF`

---

## 6. Farbschema

| Element | Farbe | Hex |
|---------|-------|-----|
| Hauptfarbe / Average HC | Orange | `#FF6600` |
| Missing HC / Day | Grau | `#808080` |
| Country Average (Benchmark) | Hellorange | `#FFAA44` |
| Ø Region | Dunkelgrau | `#555555` |
| Grün (gut) | | `#00B050` |
| Gelb (mittel) | | `#FFC000` |
| Rot (schlecht) | | `#FF0000` |
| Hintergrund | Hellgrau | `#F5F5F5` |

---

## 7. Slicer-Konfiguration

| Slicer | Feld | Typ | Standard |
|--------|------|-----|---------|
| Business Area | `SickLeave_Data[Area]` | Dropdown | EH |
| Year | `SickLeave_Data[Year]` | Dropdown | Aktuelles Jahr |
| Period | `SickLeave_Data[Period]` | Dropdown | Mehrfachauswahl |

**Wichtig:** Slicer auf Seite 1 und Seite 2 synchronisieren:
Ansicht → Slicer synchronisieren → alle Seiten aktivieren

---

## 8. Bekannte Einschränkungen

1. **TC = HC:** Der Bradford Factor und alle HC-basierten KPIs verwenden HC als Proxy für TC (Teilzeit-korrigierter Headcount), da kein TC in den Quelldaten vorliegt.

2. **Doctor Appointment Hours:** In einigen Dealerships leer → wird als 0 behandelt.

4. **Benchmark nur auf Country-Ebene:** Der Benchmark-Wert wird auf Dealership-Ebene unverändert angezeigt (kein Dealership-spezifischer Benchmark verfügbar).

5. **Vorjahresvergleich erfordert Einzel-Slicer-Auswahl:** Die PY-Measures funktionieren nur korrekt, wenn im Year-Slicer genau ein Jahr ausgewählt ist.
