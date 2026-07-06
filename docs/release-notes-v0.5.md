# v0.5

Großes Update: Protokoll gegen die Original-Dokumentation und die Protokoll-XMLs der BatteryMonitor-Software verifiziert, viele Bugfixes, neue Funktionen und überarbeitete Weboberfläche.

## Neu

- **Multi-Pack-Unterstützung**: mehrere BMS am selben Bus (`self.packs = ["00", "01", ...]`), Telemetrie/Alarme/Settings rotieren über die Adressen. ⚠️ **Bisher nur mit einem Pack getestet** — Feedback willkommen.
- **Geräteinfo (51H)**: Modell + CAN-Protokoll als Überschrift auf der Weboberfläche und im MQTT-JSON (`DeviceInfo`)
- **Settings-/Standby-Monitor (47H)**: stündlicher Read des Parameterblocks; zeigt an, ob die 48h-Standby-Abschaltung aktiv ist (inkl. Register 4D), mit automatischem Retry
- **Lern-Modus**: passives Mitschneiden des kompletten RS485-Verkehrs (Web-Button oder Konsole `SeplosLearn 1/0`) — Polling pausiert, Frames werden klassifiziert im Web und in der Konsole angezeigt. Ideal, um Kommandos der Original-Software zu analysieren.
- **Web-Buttons**: BMS-Shutdown und SOC-Fix, beide mit Bestätigungsdialog
- **Register-Referenz**: komplette Parameter-/Bit-Tabelle aus den BatteryMonitor-XMLs unter `docs/seplos_register.md`

## Fixes

- Adress-Bug im Alarm-Parser (Warnings landeten bei Multi-Pack unter falscher Adresse)
- `requestUpdate` wurde mit zu vielen Argumenten aufgerufen (Laufzeitfehler)
- LCHKSUM-Berechnung korrigiert (Nibble-Summe statt ASCII-Ziffern; brach bei Hex-Ziffern a–f)
- Empfang validiert jetzt LENGTH **und** CHKSUM jedes Frames; Störzeichen und fremde Master am Bus (z.B. parallel laufende PC-Software) stören nicht mehr
- Serieller Empfang im 100-ms-Takt statt 250 ms — keine Pufferüberläufe mehr bei langen Frames (Settings-Block ~350 Bytes)
- Lüfterregelung nutzt die echte Sensoranzahl (Crash bei <6 Sensoren) und sendet `Dimmer` nur bei Änderung
- SOC-Fix bei Tiefentladung löst nur noch ohne große Entladelast aus (Spannungseinbruch unter Last) und adressiert das betroffene Pack
- Diverse KeyError-Absicherungen, Typos in Warnungstexten (MQTT-Keys `ProtocolVersion`, `WarningTemperature` umbenannt!)

## Weboberfläche

- SOC-Balken mit Farbindikator (grün/orange/rot), Kapazität, SOH und Zyklen in einer Zeile
- Zellspannungs-Gitter (4×4) mit Min- (blau) und Max-Markierung (rot)
- Warnungen nur noch wenn vorhanden (rot mit ⚠), Balancing-Anzeige blau
- Zeile „Standby-Abschaltung: aktiv/aus · Reg4D"
- Label „Temp BMS" statt „Temp Umgebung · BMS"

## Sicherheitshinweise

- BMS-Shutdown per RS485 ist eine Einbahnstraße — Aufwecken nur per Reset-Taste, Ladespannung oder Batterie ab-/anklemmen
- Vorsicht mit „Switch shut down function" in der PC-Software: aktiv ohne angeschlossenen externen Schalter = BMS schaltet nach jedem Start sofort ab
- Einzelregister-Schreiben (49H) wird von der Firmware nicht unterstützt (außer SOC-Register 0x3B); Einstellungen nur als Komplett-Block via A1H
