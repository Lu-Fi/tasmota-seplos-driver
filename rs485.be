####################################################
##
##  Seplos BMS driver
##  v 0.5
##  Lutz Fiebach
##
##  Frame: SOI(7E) VER(2) ADR(2) CID1(2) CID2(2) LENGTH(4) INFO(n) CHKSUM(4) EOI(0D)
##  Doku: SEPLOS BMS Communication Protocol V2.0
##
##  Features: Telemetrie (42H), Alarme (44H), Geraeteinfo (51H), Settings-Monitor (47H),
##  Multi-Pack (self.packs), Lern-Modus (SeplosLearn 1/0), Shutdown-/SOC-Fix-Buttons,
##  Luefterregelung (nur Pack 0), SOC-Fix bei Tiefentladung ohne Last
##
####################################################
import webserver
import string
import json

class rs485 : Driver

    var lastSocUpdate
    var updateTeleperiod
    var updateInfo

    var debug
    var rxWait
    var rxBuffer

    var sep
    var sepl
    var warnings

    var fanTemp
    var socFixMaxLoad

    var learnMode    # 1 = Polling aus, alle Bus-Frames mitschneiden
    var learnLog     # letzte mitgeschnittene Frames
    var learnCount

    var packs        # Liste der BMS-Adressen (DIP), z.B. ["00"] oder ["00", "01"]
    var packIdxT     # Rotationsindex Telemetrie
    var packIdxA     # Rotationsindex Alarme
    var packIdxS     # Rotationsindex Settings
    var settingsTimer
    var infoTimer
    var pendingCmd   # zuletzt gesendetes CID2
    var waitInfo     # Geraeteinfo-Antwort (51H) ausstehend
    var waitSettings # Settings-Antwort (47H) ausstehend

    static ser = serial(17, 16, 19200, serial.SERIAL_8N1)

    def init()

        self.rxWait = 0
        self.fanTemp = 26.5
        self.socFixMaxLoad = 5.0 # max. Entladestrom (A), bei dem der SOC-Fix noch ausgeloest wird

        self.learnMode = 0
        self.learnLog = []
        self.learnCount = 0

        self.packs = ["00"]  # weitere Packs hier eintragen, z.B. ["00", "01"]
        self.packIdxT = 0
        self.packIdxA = 0
        self.packIdxS = 0
        self.settingsTimer = 20   # erster Settings-Read 20s nach Start, danach stuendlich
        self.infoTimer = 10       # Geraeteinfo 10s nach Start, Retry alle 60s bis Erfolg
        self.pendingCmd = ""
        self.waitInfo = false
        self.waitSettings = false
        self.sep = ", "
        self.sepl = {}
        self.lastSocUpdate = {}
        self.warnings = [
            #bit (1=multiple,2=info,4=field), message
            [1, "Cell"],
            [1, "Temperature"],
            [0, "Charging and discharging current"],
            [0, "Pack voltage"],
            [0, ""], #Number of custom alarms P=20 (skip)
            [0, [
                "Voltage sensing failure",
                "Temperature sensing failure",
                "Current sensing failure",
                "Power switch failure",
                "Cell voltage difference sensing failure",
                "Charging switch failure",
                "Discharging switch failure",
                "Current limit switch failure"
                ],"1"
            ],
            [0, [
                "Cell over voltage warning",
                "Cell over voltage protection",
                "Cell low voltage warning",
                "Cell low voltage protection",
                "Pack over voltage warning",
                "Pack over voltage protection",
                "Pack low voltage warning",
                "Pack low voltage protection"
                ],"2"
            ],
            [0, [
                "Charging high temperature warning",
                "Charging high temperature protection",
                "Charging low temperature warning",
                "Charging low temperature protection",
                "Discharging high temperature warning",
                "Discharging high temperature protection",
                "Discharging low temperature warning",
                "Discharging low temperature protection"
                ],"3"
            ],
            [0, [
                "Ambient high temperature warning",
                "Ambient high temperature protection",
                "Ambient low temperature warning",
                "Ambient low temperature protection",
                "Component high temperature warning",
                "Component high temperature protection",
                "Heating",
                "Reserved"
                ],"4"
            ],
            [0, [
                "Charging over current warning",
                "Charging over current protection",
                "Discharging over current warning",
                "Discharging over current protection",
                "Transient over current protection",
                "Output short circuit protection",
                "Transient over current lock",
                "Output short circuit lock"
                ],"5"
            ],
            [0, [
                "Charging high voltage protection",
                "Intermittent power supplement waiting",
                "Remaining capacity warning",
                "Remaining capacity protection",
                "Cell low voltage forbidden charging",
                "Output reverse connection protection",
                "Output connection failure",
                "Internal bit"
                ],"6"
            ],
            [0, [
                "Discharge switch status",
                "Charge switch status",
                "Current limit switch status",
                "Heating switch status",
                "Reserved",
                "Reserved",
                "Reserved",
                "Reserved"
                ],"Power Status"
            ],
            [2, [ "1", "2", "3", "4", "5", "6", "7", "8"],"CellEqualization"
            ],
            [2, [ "9", "10", "11", "12", "13", "14", "15", "16"],"CellEqualization"
            ],
            [4, [
                "Discharge",
                "Charge",
                "Floating charge",
                "Reserved",
                "Standby",
                "Power off",
                "Reserved",
                "Reserved"
                ],"SystemStatus"
            ],
            [2, [ "1", "2", "3", "4", "5", "6", "7", "8"],"CellDisconnection"
            ],
            [2, [ "9", "10", "11", "12", "13", "14", "15", "16"],"CellDisconnection"
            ],
            [0, [
                "Internal bit",
                "Internal bit",
                "Internal bit",
                "Internal bit",
                "Auto charging wait",
                "Manual charging wait",
                "Internal bit",
                "Internal bit"
                ],"7"
            ],
            [0, [
                "EEP storage failure",
                "RTC clock failure",
                "No calibration of voltage",
                "No calibration of current",
                "No calibration of null point",
                "Internal bit",
                "Internal bit",
                "Internal bit"
                ],"8"
            ]
        ]
        self.debug = 0

        self.updateInfo = 0
        self.updateTeleperiod = 0

        self.rxBuffer = bytes()

        #self.web_add_main_button()
    end

    #################################################
    # Protokoll-Helfer
    #################################################

    # CHKSUM: Summe aller ASCII-Zeichen (ohne SOI/EOI/CHKSUM), mod 65536, invertiert + 1
    def frameChecksum(payload)

        var c = 0
        for i:0..payload.size() - 1
            c += payload[i]
        end
        return ( ~c + 1 ) & 0xFFFF
    end

    # LENGTH-Feld (LCHKSUM + LENID): Nibble-Summe von LENID, mod 16, invertiert + 1
    def lengthField(lenid)

        var lchk = ((lenid >> 8) & 0xF) + ((lenid >> 4) & 0xF) + (lenid & 0xF)
        lchk = ( ~lchk + 1 ) & 0xF
        return string.format("%X%03X", lchk, lenid)
    end

    #################################################
    # Lern-Modus
    #################################################

    def setLearn(v)

        self.learnMode = v ? 1 : 0

        if self.learnMode == 1
            self.learnLog = []
            self.learnCount = 0
            print("SEPLOS LEARN: aktiv - Polling pausiert, Bus wird mitgeschnitten")
        else
            print("SEPLOS LEARN: beendet")
        end
    end

    #Frame als sichere ASCII-Darstellung (fuer Web/Konsole)
    def learnAscii(f)

        var txt = ""
        for i:0..f.size() - 1

            var c = f[i]
            if c >= 32 && c <= 126 && c != 60 && c != 62 && c != 38 && c != 34 && c != 39
                txt = txt .. string.char(c)
            elif c == 0x0D
                #EOI weglassen
            else
                txt = txt .. "."
            end
        end
        return txt
    end

    #Frame grob klassifizieren (Kommando vs. Antwort)
    def learnClassify(f)

        if f.size() < 13 return "unvollstaendig" end

        var adr = f[3..4].asstring()
        var cid2 = f[7..8].asstring()
        var lenid = f[10..12].asstring()

        #RTN-Codes 00-07 / E1-E4 = Antwort vom BMS
        if cid2[0] == "0" || cid2[0] == "E"
            return string.format("BMS-Antwort RTN %s, Adr %s, LENID %s", cid2, adr, lenid)
        end
        return string.format("Kommando CID2 %s an Adr %s, LENID %s", cid2, adr, lenid)
    end

    def learnFrame(f)

        self.learnCount += 1

        var entry = {
            'i': self.learnCount,
            'd': self.learnClassify(f),
            'f': self.learnAscii(f)
        }

        self.learnLog.push(entry)
        if size(self.learnLog) > 16
            self.learnLog.pop(0)
        end

        #auch in die Tasmota-Konsole (zum Kopieren)
        print(string.format("SEPLOS LEARN #%i [%s] %s", entry['i'], entry['d'], entry['f']))
    end

    #################################################
    # Empfang
    #################################################

    def rxCmd(cmd)

        # cmd = kompletter Frame inkl. SOI (0x7E) und EOI (0x0D)
        if cmd.size() < 18 || cmd[0] != 0x7E return end

        var infoSize = int('0x' + cmd[10..12].asstring())

        # Laengenpruefung: SOI(1) + Header(12) + INFO + CHKSUM(4) + EOI(1)
        if cmd.size() != infoSize + 18

            if self.debug == 1
                print(string.format("SEPLOS: length mismatch (LENID %i, frame %i)", infoSize, cmd.size()))
            end
            return
        end

        # Checksumme pruefen
        var chkRecv = int('0x' + cmd[cmd.size()-5..cmd.size()-2].asstring())
        var chkCalc = self.frameChecksum(cmd[1..cmd.size()-6])
        if chkRecv != chkCalc

            if self.debug == 1
                print(string.format("SEPLOS: checksum error (recv %04X, calc %04X)", chkRecv, chkCalc))
            end
            return
        end

        if self.debug == 1
            print(string.format("SIZE: %i, FN: %s, DATA: %s", infoSize, cmd[7..8].asstring(), cmd.tohex()))
        end

        # RTN-Code pruefen (00 = Normal)
        if cmd[7..8].asstring() != "00" return end

        var bmsAddress = int('0x' + cmd[3..4].asstring())

        ##150 (75 byte) = Telemetry, 98 (49 byte) = Telecommand/Alarm
        ##Warteflags bleiben gesetzt, bis die passende Antwort kam --
        ##dazwischen koennen fremde Frames liegen (z.B. parallel pollende PC-Software)
        if infoSize == 150
            self.rxTelemetry(bmsAddress, cmd)
        elif infoSize == 98
            self.rxAlarm(bmsAddress, cmd)
        elif self.waitSettings && infoSize > 200
            self.rxSettings(bmsAddress, cmd)
            self.waitSettings = false
        elif self.waitInfo && infoSize < 200
            self.rxDeviceInfo(bmsAddress, cmd)
            self.waitInfo = false
        end
    end

    #Settings-Block (47H): DATAFLAG + n(2B-Reg) + n(1B-Reg) + n(Bit-Bytes) + Modellname
    def rxSettings(bmsAddress, cmd)

        if ! self.sepl.contains(bmsAddress)
            self.sepl[bmsAddress] = {}
        end

        var i = 15  # INFO-Start (13) + DATAFLAG (2)

        var n2 = int('0x' + cmd[i..i+1].asstring())
        i += 2 + n2 * 4  # 2-Byte-Register ueberspringen

        var n1 = int('0x' + cmd[i..i+1].asstring())
        i += 2
        var p1 = []
        for j:0..n1 - 1
            p1.push(int('0x' + cmd[i..i+1].asstring()))
            i += 2
        end

        var nb = int('0x' + cmd[i..i+1].asstring())
        i += 2
        var bits = []
        for j:0..nb - 1
            bits.push(int('0x' + cmd[i..i+1].asstring()))
            i += 2
        end

        var s = {}

        #1-Byte-Register: Index = Reg - 0x3C
        if n1 > 0x4D - 0x3C
            s['StandbyShutdownDelay'] = p1[0x4D - 0x3C]
        end

        #Bit-Byte 7: Funktions-Schalter
        if nb > 7
            s['SwitchShutdownFunction'] = bits[7] & 1
            s['StandbyShutdownFunction'] = (bits[7] >> 1) & 1
            s['FunctionByte7'] = string.format("%02X", bits[7])
        end

        self.sepl[bmsAddress]['Settings'] = s
        self.settingsTimer = 3600  #Erfolg -> naechster Read in 1h

        #Konsolen-Log fuer Langzeit-Beobachtung (Countdown-These Reg 4D)
        print(string.format(
            "SEPLOS SETTINGS Pack %i: Reg4D=%ih, StandbyShutdown=%s, SwitchShutdown=%s",
            bmsAddress,
            s.find('StandbyShutdownDelay', -1),
            s.find('StandbyShutdownFunction', -1) == 1 ? "ON" : "off",
            s.find('SwitchShutdownFunction', -1) == 1 ? "ON" : "off"))
    end

    def rxDeviceInfo(bmsAddress, cmd)

        if ! self.sepl.contains(bmsAddress)
            self.sepl[bmsAddress] = {}
        end

        #INFO als ASCII dekodieren, nur unkritische Zeichen uebernehmen
        var info = cmd[13..cmd.size()-6]
        var txt = ""
        var last = ""
        var i = 0

        while i < info.size() - 1

            var c = int('0x' + info[i..i+1].asstring())

            if (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) ||
               c == 32 || c == 45 || c == 46 || c == 95 || c == 47 || c == 58 || c == 44

                var ch = string.char(c)
                if ch != " " || last != " "
                    txt = txt .. ch
                end
                last = ch
            end
            i += 2
        end

        self.sepl[bmsAddress]['DeviceInfo'] = txt
    end

    def rxTelemetry(bmsAddress, cmd)

        var offset = 17
        self.updateTeleperiod = 15

        if ! self.sepl.contains(bmsAddress)
            self.sepl[bmsAddress] = {}
        end
        if ! self.sepl[bmsAddress].contains('Fan')
            self.sepl[bmsAddress]['Fan'] = 0
        end

        var bms = self.sepl[bmsAddress]

        #protocol version
        bms['ProtocolVersion'] = int(cmd[1..2].asstring()) / 10.0

        #cell count
        var nCells = int( '0x' + cmd[offset..offset+1].asstring() )
        offset += 2

        #cell voltages
        var cells = {}
        cells['min'] = 10000
        cells['max'] = 0
        cells['count'] = nCells

        for i:0..nCells - 1

            cells[i] = int( '0x' + cmd[offset..offset+3].asstring() )

            if cells[i] < cells['min'] cells['min'] = cells[i] end
            if cells[i] > cells['max'] cells['max'] = cells[i] end

            offset += 4
        end
        cells['diff'] = cells['max'] - cells['min']
        bms['Cells'] = cells

        #temperatures
        var temps = {}
        var nSensors = int( '0x' + cmd[offset..offset+1].asstring() )
        offset += 2

        temps['count'] = nSensors

        for i:0..nSensors - 1

            temps[i] = ( int( '0x' + cmd[offset..offset+3].asstring() ) - 2731.0 ) / 10.0
            offset += 4
        end
        bms['Temperatures'] = temps

        #current (signed)
        bms['Current'] = bytes(cmd[offset..offset+3].asstring()).geti(0,-2) / 100.00
        offset += 4

        #pack voltage
        bms['Voltage'] = int('0x'+cmd[offset..offset+3].asstring()) / 100.00
        offset += 4

        #remaining capacity
        bms['RemainingCapacity'] = int('0x'+cmd[offset..offset+3].asstring()) / 100.00
        offset += 4

        #customize info p=10
        bms['CustomizeInfo'] = int('0x'+cmd[offset..offset+1].asstring())
        offset += 2

        #battery capacity
        bms['BatteryCapacity'] = int('0x'+cmd[offset..offset+3].asstring()) / 100.00
        offset += 4

        #SOC (1 promille)
        bms['SOC'] = int('0x'+cmd[offset..offset+3].asstring()) / 10.00
        offset += 4

        #rated capacity
        bms['RatedCapacity'] = int('0x'+cmd[offset..offset+3].asstring()) / 100.00
        offset += 4

        #cycle life
        bms['CycleLife'] = int('0x'+cmd[offset..offset+3].asstring())
        offset += 4

        #SOH (1 promille)
        bms['SOH'] = int('0x'+cmd[offset..offset+3].asstring()) / 10.00
        offset += 4

        #port voltage
        bms['PortVoltage'] = int('0x'+cmd[offset..offset+3].asstring()) / 100.00
        offset += 4
    end

    def rxAlarm(bmsAddress, cmd)

        var offset = 17
        self.updateInfo = 30

        if ! self.sepl.contains(bmsAddress)
            self.sepl[bmsAddress] = {}
        end

        self.sepl[bmsAddress]['Warnings'] = {}
        self.sepl[bmsAddress]['Warnings']['Global'] = ""

        var bms = self.sepl[bmsAddress]
        var warn = self.sepl[bmsAddress]['Warnings']

        for e:self.warnings

            var sep = ""

            #Simple Warning (Anzahl + n Byte-Alarme)
            if e[0] & 1 == 1

                var n = int( '0x' + cmd[offset..offset+1].asstring() )
                offset += 2

                for i:0..n - 1

                    if int('0x'+cmd[offset..offset+1].asstring())

                        if ! warn.contains(e[1])
                            warn[e[1]] = ""
                        end
                        warn[e[1]] = warn[e[1]]..sep..(i+1)
                        sep = self.sep
                    end
                    offset += 2
                end
            else

                #Global (einzelnes Byte-Alarm-Feld)
                if e.size() == 2

                    if size(e[1]) && int('0x'+cmd[offset..offset+1].asstring())

                        if size(warn['Global']) > 0
                            sep = self.sep
                        end
                        warn['Global'] = warn['Global']..sep..e[1]
                    end
                #Categorized (Bit-Alarme)
                elif e.size() == 3

                    var w = warn

                    if e[0] & 4 == 4
                        w = bms
                    end

                    if w.contains(e[2]) && ( e[0] & 4 != 4 )

                        if size(w[e[2]]) > 0
                            sep = self.sep
                        end
                    else
                        w[e[2]] = ""
                    end

                    var flags = int('0x'+cmd[offset..offset+1].asstring())
                    var nBits = e[1].size()

                    for i:0..nBits - 1

                        if flags & (1<<i) > 0

                            w[e[2]] = w[e[2]]..sep..e[1][i]
                            sep = self.sep
                        end
                    end
                end
                offset += 2
            end
        end
    end

    #################################################
    # Web-Oberflaeche
    #################################################

    def webCellGrid(cells)

        var n = cells['count']
        var grid = "<tr><td colspan='2' style='padding:0 0 8px'><table style='width:100%;border-spacing:2px;text-align:center;font-size:11px'>"

        var i = 0
        while i < n

            if i % 4 == 0 grid = grid .. "<tr>" end

            var st = ""
            if cells[i] == cells['min']
                st = ";color:#4da3ff;font-weight:bold"
            elif cells[i] == cells['max']
                st = ";color:#ff6b5e;font-weight:bold"
            end

            grid = grid .. string.format(
                "<td style='background:rgba(128,128,128,0.13);border-radius:3px;padding:2px 0%s'><span style='opacity:0.55'>%d</span> %.3f</td>",
                st, i + 1, cells[i] / 1000.0)

            i += 1
            if i % 4 == 0 grid = grid .. "</tr>" end
        end

        if n % 4 != 0 grid = grid .. "</tr>" end

        return grid .. "</table></td></tr>"
    end

    def web_sensor()

        #- exit if not initialized -#
        if size(self.sepl) == 0 return nil end

        var msg = ""

        #Lern-Modus: Banner + mitgeschnittene Frames (neueste zuerst)
        if self.learnMode == 1

            msg = msg .. "<tr><td colspan='2' style='background:#8a6d1a;border-radius:4px;text-align:center;font-size:12px;padding:3px'>Lern-Modus aktiv &ndash; Polling pausiert (Werte eingefroren)</td></tr>"

            var i = size(self.learnLog) - 1
            while i >= 0

                var e = self.learnLog[i]
                msg = msg .. string.format(
                    "<tr><td colspan='2' style='font-size:10px'><span style='opacity:0.6'>#%i %s</span><br><span style='font-family:monospace;word-break:break-all'>%s</span></td></tr>",
                    e['i'], e['d'], e['f'])
                i -= 1
            end
        end

        for b:self.sepl.keys()

            var bms = self.sepl[b]

            #Geraeteinfo (51H) zentriert ueber dem Block
            if bms.contains('DeviceInfo') && size(bms['DeviceInfo']) > 0
                msg = msg .. string.format(
                    "<tr><td colspan='2' style='text-align:center;font-size:12px;opacity:0.65;padding:8px 0 6px'>%s</td></tr>", bms['DeviceInfo'])
            end

            if bms.contains('Cells')

                var power = bms['Voltage'] * bms['Current']

                #Kopfzeile: BMS, Spannung, Strom, Leistung
                msg = msg .. string.format(
                    "<tr><td colspan='2' style='padding-top:4px;font-size:13px'><b>BMS %d</b> &nbsp; %.2f V &nbsp; %.2f A &nbsp; <b>%.0f W</b></td></tr>",
                    b, bms['Voltage'], bms['Current'], power)

                #SOC-Balken
                var soc = bms['SOC']
                if soc < 0 soc = 0 elif soc > 100 soc = 100 end
                var socCol = soc >= 40 ? "#5cb85c" : ( soc >= 15 ? "#f0ad4e" : "#d9534f" )

                var socInt = int(soc + 0.5)
                msg = msg .. string.format(
                    "<tr><td colspan='2'><div style='height:10px;border-radius:5px;margin-top:4px;background:linear-gradient(90deg,%s %i%%,rgba(128,128,128,0.25) %i%%)'></div><div style='font-size:11px;text-align:center;padding:3px 0 8px'>SOC %.1f%% &nbsp;&middot;&nbsp; %.1f / %.1f Ah &nbsp;&middot;&nbsp; SOH %.1f%% &nbsp;&middot;&nbsp; %i Zyklen</div></td></tr>",
                    socCol, socInt, socInt, bms['SOC'], bms['RemainingCapacity'], bms['BatteryCapacity'], bms['SOH'], bms['CycleLife'])

                #Zellen-Gitter (min blau, max rot)
                msg = msg .. self.webCellGrid(bms['Cells'])

                msg = msg .. string.format(
                    "{s}Zellen min / max / \xCE\x94{m}%.3f / %.3f V &middot; %i mV{e}",
                    bms['Cells']['min'] / 1000.0, bms['Cells']['max'] / 1000.0, bms['Cells']['diff'])

                #Temperaturen
                var temps = bms['Temperatures']
                if temps['count'] >= 6

                    msg = msg .. string.format(
                        "{s}Temp Zellen{m}%.1f / %.1f / %.1f / %.1f &deg;C{e}",
                        temps[0], temps[1], temps[2], temps[3])
                    msg = msg .. string.format(
                        "{s}Temp BMS{m}%.1f &middot; %.1f &deg;C{e}",
                        temps[4], temps[5])
                else

                    var tTxt = ""
                    var tSep = ""
                    for t:0..temps['count'] - 1
                        tTxt = tTxt .. tSep .. string.format("%.1f", temps[t])
                        tSep = " / "
                    end
                    msg = msg .. string.format("{s}Temperaturen{m}%s &deg;C{e}", tTxt)
                end

                if bms.contains('Fan') && bms['Fan'] > 0
                    msg = msg .. string.format("{s}L&uuml;fter{m}%i%%{e}", bms['Fan'])
                end
            end

            #Systemstatus (Discharge/Charge/Standby...)
            if bms.contains('SystemStatus') && size(bms['SystemStatus']) > 0
                msg = msg .. string.format("{s}Status{m}%s{e}", bms['SystemStatus'])
            end

            #Standby-Abschaltung (aus Settings 47H)
            if bms.contains('Settings')

                var st = bms['Settings']
                var stTxt = st.find('StandbyShutdownFunction', 0) == 1 ?
                    "<span style='color:#f0ad4e'>aktiv</span>" : "<span style='color:#5cb85c'>aus</span>"
                msg = msg .. string.format(
                    "{s}Standby-Abschaltung{m}%s &middot; Reg4D: %i h{e}",
                    stTxt, st.find('StandbyShutdownDelay', -1))
            end

            #Warnungen (nur nicht-leere), Balancing/Schalter neutral, Rest rot
            if bms.contains('Warnings')

                for e:bms['Warnings'].keys()

                    var v = bms['Warnings'][e]
                    if size(v) == 0 continue end

                    if e == 'CellEqualization'
                        msg = msg .. string.format(
                            "<tr><td colspan='2' style='font-size:12px;color:#4da3ff'>Balancing: Zelle %s</td></tr>", v)
                    elif e == 'Power Status'
                        msg = msg .. string.format("{s}Schalter{m}%s{e}", v)
                    elif e == 'Cell'
                        msg = msg .. string.format(
                            "<tr><td colspan='2' style='font-size:12px;color:#ff6b5e'>&#9888; Zellalarm: Zelle %s</td></tr>", v)
                    elif e == 'Temperature'
                        msg = msg .. string.format(
                            "<tr><td colspan='2' style='font-size:12px;color:#ff6b5e'>&#9888; Temperaturalarm: Sensor %s</td></tr>", v)
                    else
                        msg = msg .. string.format(
                            "<tr><td colspan='2' style='font-size:12px;color:#ff6b5e'>&#9888; %s</td></tr>", v)
                    end
                end
            end
        end

        if webserver.has_arg("setsoc")

            # 0x003B = SOC-Register (0.01Ah), 0x03E8 = 1000 -> 10.00Ah (alle Packs)
            for a:self.packs
                self.requestUpdate(a, "49", "003B03E8")
            end
        end

        if webserver.has_arg("bmsoff")
            self.bmsShutdown()
        end

        if webserver.has_arg("learn")
            self.setLearn(self.learnMode == 1 ? 0 : 1)
        end

        tasmota.web_send_decimal(msg)
    end

    def web_add_main_button()

        if self.learnMode == 1
            webserver.content_send(
                "<p></p><button style='background:#8a6d1a' onclick='la(\"&learn=1\");'>Lern-Modus beenden</button>")
        else
            webserver.content_send(
                "<p></p><button onclick='la(\"&learn=1\");'>Lern-Modus starten</button>")
        end

        webserver.content_send(
            "<p></p><button onclick='if(confirm(\"SOC auf 10 Ah (~7.4%) setzen?\")){la(\"&setsoc=1\");}'>SOC-Fix (10 Ah)</button>")
        webserver.content_send(
            "<p></p><button style='background:#a33c3c' onclick='if(confirm(\"BMS wirklich abschalten?\\n\\nWiedereinschalten geht NUR am Geraet (Reset-Taste ~3s) oder durch Anlegen von Ladespannung!\")){la(\"&bmsoff=1\");}'>BMS abschalten</button>")
    end

    def json_append()

        tasmota.response_append(
            ',"seplos":'..json.dump(self.sepl))
    end

    #################################################
    # Senden
    #################################################

    def requestUpdate(adapter, function, data)

        if self.debug != 1
            self.rxWait = 12  # 1.2s Antwortfenster (100ms-Ticks)
        end

        self.pendingCmd = function
        if function == "51" self.waitInfo = true end
        if function == "47" self.waitSettings = true end

        # VER + ADR + CID1(46=Battery) + CID2 + LENGTH + INFO
        var s = bytes().fromstring(
            "20" .. adapter .. "46" .. function .. self.lengthField(size(data)) .. data)

        s += bytes().fromstring(
            string.format("%04X", self.frameChecksum(s)))

        self.ser.write(0x7e)
        self.ser.write(s)
        self.ser.write(0x0d)
    end

    def bmsShutdown()

        #Telecontrol 45H, INFO 000400 = Shutdown (fuer alle konfigurierten Packs)
        for a:self.packs
            self.requestUpdate(a, "45", "000400")
        end
    end

    def setSoc50()

        #7E ... 0x1388 = 5000 -> 50.00Ah
        self.requestUpdate("00", "49", "003B1388")
    end

    #################################################
    # Zyklen
    #################################################

    #100ms-Takt: verhindert RX-Pufferueberlauf bei langen Frames (z.B. A1H/47H Settings-Block)
    def every_100ms()

        if self.debug != 1 && self.learnMode != 1
            if ! self.rxWait return end
        end

        if self.rxWait <= 0

            if self.rxBuffer.size() > 0
                self.rxBuffer.clear()
            end
        else
            self.rxWait -= 1
        end

        if self.ser.available()

            self.rxBuffer += self.ser.read()

            if self.debug == 1 || self.learnMode == 1
                self.rxWait = 5
            else
                self.rxWait += 1
            end
        end

        #alle vollstaendigen Frames (bis EOI) verarbeiten
        var i = 0
        while i < self.rxBuffer.size()

            if self.rxBuffer[i] == 0x0D

                var frame = self.rxBuffer[0..i]

                if self.rxBuffer.size() > ( i + 1 )
                    self.rxBuffer = self.rxBuffer[i+1..self.rxBuffer.size()-1]
                else
                    self.rxBuffer = bytes()
                end

                #fuehrende Stoerzeichen bis SOI verwerfen
                var s = 0
                while s < frame.size() && frame[s] != 0x7E
                    s += 1
                end

                if s < frame.size()

                    if self.learnMode == 1
                        self.learnFrame(frame[s..frame.size()-1])
                    end

                    try
                        self.rxCmd(frame[s..frame.size()-1])
                    except .. as err, msg
                        print(string.format("SEPLOS: rx error %s: %s", err, msg))
                    end
                end

                i = 0
            else
                i += 1
            end
        end
    end

    def every_second()

        #Lern-Modus: kein Polling, nur mithoeren
        if self.learnMode == 1 return end

        if self.updateTeleperiod <= 0

            var addr = self.packs[self.packIdxT]
            self.packIdxT = ( self.packIdxT + 1 ) % size(self.packs)
            self.requestUpdate(addr, "42", addr)
            self.updateTeleperiod = 15
            return
        else
            self.updateTeleperiod -= 1
        end

        #Geraeteinfo anfordern, Retry alle 60s bis alle Packs sie haben
        #(eigener Timer: bei parallel pollender PC-Software bleibt updateTeleperiod sonst dauerhaft auf 15)
        if self.infoTimer > 0
            self.infoTimer -= 1
        end

        if self.infoTimer <= 0

            self.infoTimer = 60

            for a:self.packs

                var ai = int('0x' + a)
                if self.sepl.contains(ai) && ! self.sepl[ai].contains('DeviceInfo')

                    self.requestUpdate(a, "51", "")
                    return
                end
            end
        end

        #Settings-Block stuendlich lesen (Standby-Countdown beobachten)
        if self.settingsTimer > 0
            self.settingsTimer -= 1
        end

        if self.settingsTimer <= 0

            var addr = self.packs[self.packIdxS]
            self.packIdxS = ( self.packIdxS + 1 ) % size(self.packs)
            self.requestUpdate(addr, "47", addr)
            #Retry in 60s; bei Erfolg setzt rxSettings() auf 3600
            self.settingsTimer = 60
            return
        end

        if self.updateInfo <= 0

            var addr = self.packs[self.packIdxA]
            self.packIdxA = ( self.packIdxA + 1 ) % size(self.packs)
            self.requestUpdate(addr, "44", addr)
            self.updateInfo = 30
            return
        else
            self.updateInfo -= 1
        end

        #Luefterregelung (nur BMS 0)
        if self.updateTeleperiod >= 14

            if self.sepl.contains(0) && self.sepl[0].contains('Temperatures') && self.sepl[0].contains('Fan')

                var temps = self.sepl[0]['Temperatures']
                var maxTemp = 0

                for i:0..temps['count'] - 1

                    if temps[i] > maxTemp
                        maxTemp = temps[i]
                    end
                end

                var fan = self.sepl[0]['Fan']

                if ( maxTemp > self.fanTemp && fan <= 0 ) || ( maxTemp > ( self.fanTemp - 1 ) && fan > 0 )

                    var fanVal = int(( maxTemp - self.fanTemp ) * 10) + 60

                    if fanVal > 100
                        fanVal = 100
                    elif fanVal < 60
                        fanVal = 60
                    end

                    if fanVal != fan
                        tasmota.cmd("Dimmer "..fanVal)
                        self.sepl[0]['Fan'] = fanVal
                    end
                else

                    if fan != 0
                        tasmota.cmd("Dimmer 0")
                        self.sepl[0]['Fan'] = 0
                    end
                end
            end
        end

        #SOC-Korrektur bei Tiefentladung (< 40V -> SOC auf 10Ah setzen, 60 Min Sperre)
        #nur ohne grosse Entladelast, da die Spannung unter Last einbricht
        for b:self.sepl.keys()

            if ! self.lastSocUpdate.contains(b) self.lastSocUpdate[b] = 0 end

            if self.lastSocUpdate[b] > 0
                self.lastSocUpdate[b] -= 1
            end

            if self.sepl[b].contains('Voltage') && self.sepl[b].contains('Current') &&
               int(self.sepl[b]['Voltage']) < 40 &&
               self.sepl[b]['Current'] > -self.socFixMaxLoad

                if self.lastSocUpdate[b] <= 0

                    #an die Adresse des betroffenen Packs senden
                    self.requestUpdate(string.format("%02X", b), "49", "003B03E8")
                    self.lastSocUpdate[b] = 3600 # 60 Minuten Sperre
                end
            end
        end
    end
end

rs485Driver = rs485()
tasmota.add_driver(rs485Driver)

#Konsole: SeplosLearn 1 / SeplosLearn 0
tasmota.add_cmd('SeplosLearn', def (cmd, idx, payload)
    rs485Driver.setLearn(int(payload))
    tasmota.resp_cmnd_done()
end)

print("SEPLOS Treiber geladen (v0.5)")

#tasmota.remove_driver(rs485Driver)
