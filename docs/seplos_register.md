# Seplos BMS 16S V2.0 – Register-Referenz

Quelle: BatteryMonitor V2.1.8, Agreement/16S_V20_ADDR_EN.xml

## Telecontrol-Kommandos (CID2 45H)

INFO-Format vermutlich `00` + Bit-Nr. + `00` (Shutdown = `000400` ist verifiziert, Bit 4).

| Bit | Funktion | Typ |
|-----|----------|-----|
| 0 | Discharge control | OnOff |
| 1 | Charge control | OnOff |
| 2 | Current limit control | OnOff |
| 3 | Temperature control | OnOff |
| 4 | System shutdown | Shutdown |
| 5 | Restore factory | Reset |

## Parameter-Register (CID2 47H lesen / 49H schreiben)

Schreibformat (verifiziert am SOC-Register): `00` + Register + Wert-Hex.
Beispiel: `003B03E8` = Register 3B (SOC) auf 1000 × 0.01 Ah = 10.00 Ah.

| Reg (hex) | Name | Einheit | Bytes | Skalierung |
|-----------|------|---------|-------|------------|
| 00 | Monomer high voltage alarm | V | 2 | 0.001 |
| 01 | Monomer high pressure recovery | V | 2 | 0.001 |
| 02 | Monomer low pressure alarm | V | 2 | 0.001 |
| 03 | Monomer low pressure recovery | V | 2 | 0.001 |
| 04 | Monomer overvoltage protection | V | 2 | 0.001 |
| 05 | Monomer overvoltage recovery | V | 2 | 0.001 |
| 06 | Monomer undervoltage protection | V | 2 | 0.001 |
| 07 | Monomer undervoltage recovery | V | 2 | 0.001 |
| 08 | Equalization opening voltage | V | 2 | 0.001 |
| 09 | Battery low voltage forbidden charging | V | 2 | 0.001 |
| 0A | Total pressure high pressure alarm | V | 2 | 0.01 |
| 0B | Total pressure and high pressure recovery | V | 2 | 0.01 |
| 0C | Total pressure low pressure alarm | V | 2 | 0.01 |
| 0D | Total pressure and low pressure recovery | V | 2 | 0.01 |
| 0E | Total_voltage overvoltage protection | V | 2 | 0.01 |
| 0F | Total pressure overpressure recovery | V | 2 | 0.01 |
| 10 | Total_voltage undervoltage protection | V | 2 | 0.01 |
| 11 | Total pressure undervoltage recovery | V | 2 | 0.01 |
| 12 | Harging overvoltage protection | V | 2 | 0.01 |
| 13 | Charging overvoltage recovery | V | 2 | 0.01 |
| 14 | Charging high temperature warning | Grad C | 2 | 0.1 |
| 15 | Charging high temperature recovery | Grad C | 2 | 0.1 |
| 16 | Charging low temperature warning | Grad C | 2 | 0.1 |
| 17 | Charging low temperature recovery | Grad C | 2 | 0.1 |
| 18 | Charging over temperature protection | Grad C | 2 | 0.1 |
| 19 | Charging over temperature recovery | Grad C | 2 | 0.1 |
| 1A | Charging under-temperature protection | Grad C | 2 | 0.1 |
| 1B | Charging under temperature recovery | Grad C | 2 | 0.1 |
| 1C | Discharge high temperature warning | Grad C | 2 | 0.1 |
| 1D | Discharge high temperature recovery | Grad C | 2 | 0.1 |
| 1E | Discharge low temperature warning | Grad C | 2 | 0.1 |
| 1F | Discharge low temperature recovery | Grad C | 2 | 0.1 |
| 20 | Discharge over temperature protection | Grad C | 2 | 0.1 |
| 21 | Discharge over temperature recovery | Grad C | 2 | 0.1 |
| 22 | Discharge under-temperature protection | Grad C | 2 | 0.1 |
| 23 | Discharge under temperature recovery | Grad C | 2 | 0.1 |
| 24 | Cell low temperature heating | Grad C | 2 | 0.1 |
| 25 | Cell heating recovery | Grad C | 2 | 0.1 |
| 26 | Ambient high temperature alarm | Grad C | 2 | 0.1 |
| 27 | Ambient high temperature recovery | Grad C | 2 | 0.1 |
| 28 | Ambient low temperature alarm | Grad C | 2 | 0.1 |
| 29 | Ambient low temperature recovery | Grad C | 2 | 0.1 |
| 2A | Environmental over-temperature protection | Grad C | 2 | 0.1 |
| 2B | Environmental overtemperature recovery | Grad C | 2 | 0.1 |
| 2C | Environmental under-temperature protection | Grad C | 2 | 0.1 |
| 2D | Environmental undertemperature recovery | Grad C | 2 | 0.1 |
| 2E | Power high temperature alarm | Grad C | 2 | 0.1 |
| 2F | Power high temperature recovery | Grad C | 2 | 0.1 |
| 30 | Power over temperature protection | Grad C | 2 | 0.1 |
| 31 | Power over temperature recovery | Grad C | 2 | 0.1 |
| 32 | Charging overcurrent warning | A | 2 | 0.01 |
| 33 | Charging overcurrent recovery | A | 2 | 0.01 |
| 34 | Discharge overcurrent warning | A | 2 | 0.01 |
| 35 | Discharge overcurrent recovery | A | 2 | 0.01 |
| 36 | Charge overcurrent protection | A | 2 | 0.01 |
| 37 | Discharge overcurrent protection | A | 2 | 0.01 |
| 38 | Transient overcurrent protection | A | 2 | 0.01 |
| 39 | Output soft start delay | mS | 2 | 1 |
| 3A | Battery rated capacity | Ah | 2 | 0.01 |
| 3B | SOC | Ah | 2 | 0.01 |
| 3C | Cell invalidation differential pressure | V | 1 | 0.01 |
| 3D | Cell invalidation recovery | V | 1 | 0.01 |
| 3E | Equalization opening pressure difference | V | 1 | 0.001 |
| 3F | Equalization closing pressure difference | V | 1 | 0.001 |
| 40 | Static equilibrium time | When | 1 | 1 |
| 41 | Battery number in series | String | 1 | 1 |
| 42 | Charge overcurrent delay | S | 1 | 1 |
| 43 | Discharge overcurrent delay | S | 1 | 1 |
| 44 | Transient overcurrent delay | mS | 1 | 1 |
| 45 | Overcurrent delay recovery | S | 1 | 1 |
| 46 | Overcurrent recovery times | times | 1 | 1 |
| 47 | Charge current limit delay | Minutes | 1 | 1 |
| 48 | Charge activation delay | Minutes | 1 | 1 |
| 49 | Charging activation interval | When | 1 | 1 |
| 4A | Charge activation times | times | 1 | 1 |
| 4B | Work record interval | Minutes | 1 | 1 |
| 4C | Standby recording interval | Minutes | 1 | 1 |
| 4D | Standby shutdown delay | When | 1 | 1 |
| 4E | Remaining capacity alarm | % | 1 | 1 |
| 4F | Remaining capacity protection | % | 1 | 1 |
| 50 | Interval charge capacity | % | 1 | 1 |
| 51 | Cycle cumulative capacity | % | 1 | 1 |
| 52 | Connection fault impedance | mΩ | 1 | 0.1 |
| 53 | Compensation point 1 position | String | 1 | 1 |
| 54 | Compensation point 1 impedance | mΩ | 1 | 0.1 |
| 55 | Ompensation point 2 position | String | 1 | 1 |
| 56 | Compensation point 2 impedance | mΩ | 1 | 0.1 |

## Funktions-Schalter (bit_para, Byte.Bit)

| Byte.Bit | Funktion |
|----------|----------|
| 0.0 | Voltage sensor invalidation |
| 0.1 | Temperature sensor invalidation |
| 0.2 | Current sensor invalidation |
| 0.3 | Button switch invalidation |
| 0.4 | Cell differential pressure invalidation |
| 0.5 | Charge switch invalidation |
| 0.6 | Discharge switch invalidation |
| 0.7 | Current limit switch invalidation |
| 1.0 | Monomer high voltage alarm |
| 1.1 | Monomer overvoltage protection |
| 1.2 | Monomer low pressure alarm |
| 1.3 | Monomer undervoltage protection |
| 1.4 | Total pressure high pressure alarm |
| 1.5 | Total_voltage overvoltage protection |
| 1.6 | Total pressure low pressure alarm |
| 1.7 | Total_voltage undervoltage protection |
| 2.0 | Charging high temperature warning |
| 2.1 | Charging over temperature protection |
| 2.2 | Charging low temperature warning |
| 2.3 | Charging under-temperature protection |
| 2.4 | Discharge high temperature warning |
| 2.5 | Discharge over temperature protection |
| 2.6 | Discharge low temperature warning |
| 2.7 | Discharge under-temperature protection |
| 3.0 | Ambient high temperature alarm |
| 3.1 | Environmental over-temperature protection |
| 3.2 | Ambient low temperature alarm |
| 3.3 | Environmental under-temperature protection |
| 3.4 | Power over temperature protection |
| 3.5 | Power high temperature alarm |
| 3.6 | Cell low temperature heating |
| 3.7 | PACK over-temperature heat dissipation |
| 4.0 | Charging overcurrent warning |
| 4.1 | Charge overcurrent protection |
| 4.2 | Discharge overcurrent warning |
| 4.3 | Discharge overcurrent protection |
| 4.4 | Transient current protection |
| 4.5 | Output short circuit protection |
| 4.6 | Transient overcurrent lockout |
| 4.7 | Output short circuit locking |
| 5.0 | Charging high voltage protection |
| 5.1 | Intermittent charging function |
| 5.2 | Remaining capacity alarm |
| 5.3 | Remaining capacity protection |
| 5.4 | Battery low voltage forbidden charging |
| 5.5 | Output reverse connection protection |
| 5.6 | Output connection failure |
| 5.7 | Output soft start function |
| 6.0 | Charge equalization function |
| 6.1 | Static equilibrium function |
| 6.2 | Timeout prohibits equalization |
| 6.3 | Over temperature prohibits equalization |
| 6.4 | Automatically activate charging |
| 6.5 | Manually activate charging |
| 6.6 | Take the initiative current limiting charging |
| 6.7 | Passive current limiting charging |
| 7.0 | Switch shut down function |
| 7.1 | Standby shutdown function |
| 7.2 | History record function |
| 7.3 | LCD display function |
| 7.4 | Alarm protection contact |
| 7.5 | Multi-channel extension contact |

## Kalibrier-Register (adjust_para – NICHT anfassen)

| Reg | Name | Einheit | Skalierung |
|-----|------|---------|------------|
| 0 | Zero point calibration | A | 0.01 |
| 1 | Current calibration | A | 0.01 |
| 2 | Voltage calibration | V | 0.001 |

## Fuer das 48h-Standby-Problem relevant

- Register `4D` = Standby shutdown delay (1 Byte, Stunden)
- Funktions-Schalter Byte 7 Bit 1 = Standby shutdown function (ein/aus)

Achtung: Wie die Funktions-Schalter (bit_para) uebertragen werden, ist aus der XML
nicht eindeutig ableitbar. Empfehlung: Im Lern-Modus mitschneiden, waehrend man den
Schalter in der Battery-Monitor-Software umlegt, dann exakt diesen Frame uebernehmen.