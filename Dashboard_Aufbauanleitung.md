# Sick Leave Dashboard – Power BI Aufbauanleitung

## Datenmodell

### Tabellen & Beziehungen

```
SickLeave_Data  ──── TargetHours
  Country       →→→   Country
  Year          →→→   Year
  Period        →→→   Period

SickLeave_Data  ──── Benchmark
  Country       →→→   Country
  Year          →→→   Year

DimDate         ──── SickLeave_Data
  Date          →→→   Date
```

**Kardinalitäten:** Alle Beziehungen n:1 (SickLeave_Data ist die Faktentabelle).

---

## Schritt-für-Schritt Aufbau

### 1. Daten laden (Power Query)

1. Power BI Desktop öffnen → **Daten abrufen → Ordner**
2. Den Ordner mit den CSV-Dateien auswählen
3. Im erweiterten Editor den Code aus `PowerQuery_M_Code.pq` einfügen
4. Vier Queries erstellen: `SickLeave_Data`, `TargetHours`, `Benchmark`, `DimDate`
5. Pfade in den Queries anpassen (Suche nach `C:\DeinPfad\`)

### 2. Datenmodell konfigurieren

1. **Modellansicht** öffnen
2. Beziehungen gemäß Diagramm oben erstellen
3. Sternschema prüfen – SickLeave_Data in der Mitte

### 3. Measures anlegen

1. Neue Tabelle erstellen: **Modellierung → Neue Tabelle → `Measures = {}`**
2. Alle Measures aus `DAX_Measures.dax` einzeln als **Neues Measure** einfügen
3. Measures in Anzeigeordner gruppieren (KPI, Rate, Benchmark, YoY)

---

## Dashboard-Layout (3 Report-Seiten)

### Seite 1: Übersicht (Executive Summary)

```
┌─────────────────────────────────────────────────────────────────┐
│  SLICER: Land  │  SLICER: Jahr  │  SLICER: Periode             │
├────────┬────────┬────────┬────────┬────────────────────────────┤
│  KPI   │  KPI   │  KPI   │  KPI   │                            │
│ Krank- │Krank-  │Instanz │Bench-  │  Balkendiagramm            │
│ quote  │tage/MA │  /HC   │mark Δ  │  Krankenquote je Land      │
│        │        │        │        │  (mit Benchmark-Linie)     │
├────────┴────────┴────────┴────────┤                            │
│  Liniendiagramm                   ├────────────────────────────┤
│  Krankenquote Trend über Zeit     │  Donut-Chart               │
│  (H1/H2 nach Jahr)               │  Aufteilung Abwesenheits-  │
│                                   │  arten (Krank/Pflege/Arzt) │
└───────────────────────────────────┴────────────────────────────┘
```

**Visuals im Detail:**
| Visual | Typ | Felder |
|--------|-----|--------|
| Krankenquote | KPI-Card | `Sick Leave Rate %`, `YoY Change Label` |
| Krankentage/MA | Card | `Absent Days per Employee` |
| Instanzen/HC | Card | `Instances per HC` |
| Benchmark Δ | Card | `Delta to Benchmark %` (bedingte Formatierung) |
| Trend | Liniendiagramm | X: Year+Period, Y: `Sick Leave Rate %`, Legende: Country |
| Je Land | Balken | Y: Country, X: `Sick Leave Rate %`, Linie: `Benchmark Days per Employee` |
| Aufteilung | Donut | Werte: Sick/Care/Doctor Hours |

---

### Seite 2: Dealership-Analyse (Drill-Down)

```
┌──────────────────────────────────────────────────────────────┐
│  SLICER: Land  │  SLICER: Region  │  SLICER: Jahr/Period     │
├──────────────────────────────────────────────────────────────┤
│  Treemap: Krankenquote je Dealership (Größe = HC, Farbe = %) │
├────────────────────────────┬─────────────────────────────────┤
│  Tabelle: Top/Bottom 5     │  Streudiagramm                  │
│  Dealerships nach          │  X: Instances/HC                │
│  Krankenquote              │  Y: Sick Leave Rate %           │
│                            │  Größe: HC                      │
│                            │  Farbe: Country                 │
└────────────────────────────┴─────────────────────────────────┘
```

**Bedingte Formatierung (Tabelle):**
- Krankenquote: Farbskala Grün (0%) → Rot (>10%)
- Bradford Factor: Ampel-Icons (grün/gelb/rot)

---

### Seite 3: Benchmark & Zeitvergleich

```
┌─────────────────────────────────────────────────────────────┐
│  Bullet-Chart oder gruppiertes Balkendiagramm               │
│  Krankentage/MA vs. Benchmark je Land und Jahr              │
├──────────────────────────┬──────────────────────────────────┤
│  H1 vs. H2 Vergleich     │  YoY Entwicklung                 │
│  Gestapelter Balken       │  Wasserfall-Chart               │
│  nach Period             │  Veränderung Krankenquote        │
└──────────────────────────┴──────────────────────────────────┘
```

---

## Formatierungsempfehlungen

### Farbschema
| Element | Farbe (Hex) |
|---------|-------------|
| Land 1 | `#0070C0` (Blau) |
| Land 2 | `#00B050` (Grün) |
| Land 3 | `#FF6600` (Orange) |
| Benchmark-Linie | `#FF0000` (Rot, gestrichelt) |
| Hintergrund | `#F5F5F5` (Hellgrau) |
| KPI positiv | `#00B050` |
| KPI negativ | `#FF0000` |

### Bedingte Formatierung für Krankenquote
```
< 4%   → Grün   (#00B050)
4–7%   → Gelb   (#FFC000)
> 7%   → Rot    (#FF0000)
```

---

## Wichtige Filter-Interaktionen

1. **Land-Slicer** filtert alle Visuals auf Seite 1 & 2 gleichzeitig
2. **Benchmark-Linie** zeigt immer den Länderdurchschnitt, nicht gefiltert nach Dealership
3. **Kreuzfilterung** zwischen Treemap und Tabelle auf Seite 2 aktivieren

---

## Häufige Kennzahlen-Definitionen

| Kennzahl | Formel |
|----------|--------|
| Krankenquote | Abwesenheitsstunden / (HC × Arbeitstage × Tagesarbeitszeit) |
| Krankentage/MA | Abwesenheitsstunden / (HC × Tagesarbeitszeit) |
| Instanzen/HC | Instanzen / Anzahl Mitarbeiter |
| Bradford Factor | Instanzen² × Krankentage / HC |
| Benchmark Δ | Krankentage/MA − Länder-Benchmark |

---

## Bekannte Datenlimits

- `Doctor Appointment Hours` in den Quelldaten oft leer → wird als 0 behandelt
- `Instances` in Land 1 teilweise leer → ebenfalls als 0 behandelt
- Benchmark-Datei enthält noch **Land 4** (kein eigenes CSV) → Benchmark-Measure berücksichtigt das
- Datums-Spalte in den CSVs zeigt `31.12.2025` für H1 2026 → DimDate über Year+Period verknüpfen, nicht über Date
