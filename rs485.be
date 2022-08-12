####################################################
##
##  Seplos BMS driver
##  v 0.1
##  Lutz Fiebach
##
####################################################
import webserver 
import string
import json

class rs485 : Driver

    var updateTeleperiod
    var updateInfo

    var debug
    var rxWait
    var rxBuffer
    var rxBufferReset

    var sepl
    var warnings

    static ser = serial(17, 16, 19200, serial.SERIAL_8N1)

    def init()

        self.sepl = map()
        self.warnings = [
            #bit (1=multiple,2=info,4=field), message
            [1, "Cell"],
            [1, "Temperture"],
            [0, "Charging and discharging current"],
            [0, "Pack voltage"],
            [0, "Custom"],
            [0, [
                "Voltage sensing failure",
                "Temperature sensing failure",
                "Current sensing failur",
                "Power switch failure",
                "Cell voltage difference sensing failure",
                "Charging switch failure",
                "Discharging switch failure",
                "Current limit switch failure"
                ],"Warning 1"
            ],
            [0, [
                "Cell over voltage warning",
                "Cell over voltage protection",
                "Cell low voltage warnings",
                "Cell low voltage protection",
                "Pack over voltage warnings",
                "Pack over voltage protection",
                "Pack low voltage warnings",
                "Pack low voltage protection"
                ],"Warning 2"
            ],
            [0, [
                "Charging high temperature warnings",
                "Charging high temperature protection",
                "Charging low temperature warnings",
                "Charging low temperature protection",
                "Discharging high temperature warnings",
                "Discharging high temperature protection",
                "Discharging low temperature warnings",
                "Discharging low temperature protection"
                ],"Warning 3"
            ],
            [0, [
                "Ambient high temperature warnings",
                "Ambient high temperature protection",
                "Ambient low temperature warnings",
                "Ambient low temperature protection",
                "Component high temperature warnings",
                "Component high temperature protection",
                "Heating",
                "Reserved"
                ],"Warning 4"
            ],
            [0, [
                "Charging over current warnings",
                "Charging over current protection",
                "Discharging over current warnings",
                "Discharging over current protection",
                "Transient over current protection",
                "Output short circuit protection",
                "Transient over current lock",
                "Output short circuit lock"
                ],"Warning 5"
            ],
            [0, [
                "Charging high voltage protection",
                "Intermittent power supplement waiting",
                "Remaining capacity warning",
                "Remaining capacity protectio",
                "Cell low voltage forbidden charging",
                "Output reverse connection protection",
                "Output connection failure",
                "Internal bit"
                ],"Warning 6"
            ],
            [2, [
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
            [2, [
                "Equalization of cell 01",
                "Equalization of cell 02",
                "Equalization of cell 03",
                "Equalization of cell 04",
                "Equalization of cell 05",
                "Equalization of cell 06",
                "Equalization of cell 07",
                "Equalization of cell 08"
                ],"Equalization status 1"
            ],
            [2, [
                "Equalization of cell 09",
                "Equalization of cell 10",
                "Equalization of cell 11",
                "Equalization of cell 12",
                "Equalization of cell 13",
                "Equalization of cell 14",
                "Equalization of cell 15",
                "Equalization of cell 16"
                ],"Equalization status 2"
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
                ],"System status"
            ],
            [2, [
                "Disconnection of cell 01",
                "Disconnection of cell 02",
                "Disconnection of cell 03",
                "Disconnection of cell 04",
                "Disconnection of cell 05",
                "Disconnection of cell 06",
                "Disconnection of cell 07",
                "Disconnection of cell 08"
                ],"Disconnection 1"
            ],
            [2, [
                "Disconnection of cell 09",
                "Disconnection of cell 10",
                "Disconnection of cell 11",
                "Disconnection of cell 12",
                "Disconnection of cell 13",
                "Disconnection of cell 14",
                "Disconnection of cell 15",
                "Disconnection of cell 16"
                ],"Disconnection 2"
            ],
            [0, [
                "Internal bits",
                "Internal bits",
                "Internal bits",
                "Internal bits",
                "Auto charging wait",
                "Manual charging wait",
                "Internal bits",
                "Internal bits"
                ],"Warning 7"
            ],
            [0, [
                "EEP Storage failure",
                "RTC clock failure",
                "No calibration of voltage",
                "No calibration of null point",
                "Internal bits",
                "Internal bits",
                "Internal bits",
                "Internal bits"
                ],"Warning 8"
            ],
 

        ]
        self.debug = 1

        self.updateInfo = 0
        self.updateTeleperiod = 0

        self.rxBuffer = bytes()
    end

    def rxCmd(cmd)

        var infoSize = int('0x'+cmd[10..12].asstring()) 

        ##150(75 byte) = Telemetry, 98(49 byte) = Telecommand, 48(24 byte) = Alarm
        if cmd[7..8].asstring() == "00"
            
            if infoSize == 150

                var offset = 17
                self.updateTeleperiod = 15

                #bms address
                var bmsAddress = int('0x'+cmd[3..4].asstring())
                if ! self.sepl.find(bmsAddress)

                    self.sepl[bmsAddress] = map()
                end

                #protocoll version
                self.sepl[bmsAddress]['ProtocollVersion'] = 
                    int(cmd[1..2].asstring()) / 10.0

                #cell count
                var nCells = 
                    int( '0x' + cmd[offset..offset+1].asstring() )
                offset += 2

                #cell voltages
                self.sepl[bmsAddress]['Cells'] = map()
                self.sepl[bmsAddress]['Cells']['min'] = 10000
                self.sepl[bmsAddress]['Cells']['max'] = 0
                self.sepl[bmsAddress]['Cells']['count'] = nCells

                for i:0..nCells - 1

                    self.sepl[bmsAddress]['Cells'][i] = 
                        int( '0x' + cmd[offset..offset+3].asstring() )

                    if self.sepl[bmsAddress]['Cells'][i] < self.sepl[bmsAddress]['Cells']['min']

                        self.sepl[bmsAddress]['Cells']['min'] = self.sepl[bmsAddress]['Cells'][i]
                    end

                    if self.sepl[bmsAddress]['Cells'][i] > self.sepl[bmsAddress]['Cells']['max']

                        self.sepl[bmsAddress]['Cells']['max'] = self.sepl[bmsAddress]['Cells'][i]
                    end   
                    
                    self.sepl[bmsAddress]['Cells']['diff'] = 
                        self.sepl[bmsAddress]['Cells']['max'] - self.sepl[bmsAddress]['Cells']['min']
                        
                    offset += 4
                end

                #temperatures
                self.sepl[bmsAddress]['Tempertures'] = map()
                var nSensors = 
                    int( '0x' + cmd[offset..offset+1].asstring() )
                offset += 2

                self.sepl[bmsAddress]['Tempertures']['count'] = nSensors

                for i:0..nSensors - 1

                    self.sepl[bmsAddress]['Tempertures'][i] = 
                        ( int( '0x' + cmd[offset..offset+3].asstring() ) - 2731.0 ) / 10.0
                    offset += 4
                end

                #bms current
                self.sepl[bmsAddress]['Current'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 100.00
                offset += 4

                #bms voltage
                self.sepl[bmsAddress]['Voltage'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 100.00
                offset += 4

                #bms capacity
                self.sepl[bmsAddress]['RemainingCapacity'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 100.00
                offset += 4

                #bms customize info p=10
                self.sepl[bmsAddress]['CustomizeInfo'] = 
                    int('0x'+cmd[offset..offset+1].asstring())
                offset += 2

                #bms battery capacity
                self.sepl[bmsAddress]['BatteryCapacity'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 100.00
                offset += 4

                #bms SOC
                self.sepl[bmsAddress]['SOC'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 10.00
                offset += 4

                #bms rated capacity
                self.sepl[bmsAddress]['RatedCapacity'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 100.00
                offset += 4

                #bms cycle life
                self.sepl[bmsAddress]['CycleLife'] = 
                    int('0x'+cmd[offset..offset+3].asstring())
                offset += 4

                #bms SOH
                self.sepl[bmsAddress]['SOH'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 10.00
                offset += 4

                #bms port voltage
                self.sepl[bmsAddress]['PortVoltage'] = 
                    int('0x'+cmd[offset..offset+3].asstring()) / 100.00
                offset += 4
                
            elif infoSize == 98

                var offset = 17
                self.updateInfo = 15

                #bms address
                var bmsAddress = int('0x'+cmd[2..3].asstring())
                if ! self.sepl.find(bmsAddress)
                    
                    self.sepl[bmsAddress] = map()
                end

                self.sepl[bmsAddress]['Warnings'] = list()
                self.sepl[bmsAddress]['Infos'] = list()

                for e:self.warnings

                    if e[0] & 1 == 1

                        var n = int( '0x' + cmd[offset..offset+1].asstring() ) 
                        offset +=2   
  
                        for i:0..n - 1

                            if int('0x'+cmd[offset..offset+1].asstring())

                                self.sepl[bmsAddress]['Warnings'].push(e[1].." #"..i+1)
                            end
                            offset +=2
                        end                            
                    else

                        if e.size() == 2

                            if int('0x'+cmd[offset..offset+1].asstring())

                                self.sepl[bmsAddress]['Warnings'].push(e[1])
                            end                            
                        elif e.size() == 3

                            var r = []
                            for i:0..(e[1].size())

                                if int('0x'+cmd[offset..offset+1].asstring() ) & (1<<i) > 0

                                    r.push(e[1][i])  
                                end
                            end

                            if r.size() 

                                #only info no warning / protection
                                if e[0] & 2 == 2
                                    
                                    self.sepl[bmsAddress]['Infos'].push(e[2]..": "..r.concat(", "))
                                elif e[0] & 4 == 4 

                                    self.sepl[bmsAddress][e[2]] = r.concat(", ")
                                else

                                    self.sepl[bmsAddress]['Warnings'].push(e[2]..": "..r.concat(", "))
                                end
                            end
                        end

                        offset +=2
                    end
                end
            end 
        end
    end

    def web_sensor()

         #- exit if not initialized -#
        if size(self.sepl) == 0 return nil end 

        var msg = ""

        for b:0..0 #size(self.sepl) - 1

            for c:0..self.sepl[b]['Cells']['count'] - 1

                msg = string.format(
                        "%s{s}BMS%iCell%i{m}%.3fv{e}",
                        msg, b, c + 1, self.sepl[b]['Cells'][c] / 1000.00)
            end

            msg = string.format(
                "%s{s}BMS%iCellMax{m}%.3fv{e}",
                msg, b, self.sepl[b]['Cells']['max'] / 1000.00)
                
            msg = string.format(
                "%s{s}BMS%iCellMin{m}%.3fv{e}",
                msg, b, self.sepl[b]['Cells']['min'] / 1000.00)
                
            msg = string.format(
                "%s{s}BMS%iCellDiff{m}%imv{e}",
                msg, b, self.sepl[b]['Cells']['diff'])

            for t:0..self.sepl[b]['Tempertures']['count'] - 1

                msg = string.format(
                        "%s{s}BMS%iTemp%i{m}%.1f°C{e}",
                        msg, b, t + 1, self.sepl[b]['Tempertures'][t])
            end  
            
            msg = string.format(
                "%s{s}BMS%iCurrent{m}%.2fA{e}",
                msg, b, self.sepl[b]['Current'])  
                
            msg = string.format(
                "%s{s}BMS%iVoltage{m}%.2fV{e}",
                msg, b, self.sepl[b]['Voltage']) 
            
            msg = string.format(
                "%s{s}BMS%iRemainingCapacity{m}%.2fAh{e}",
                msg, b, self.sepl[b]['RemainingCapacity'])  
                
            msg = string.format(
                "%s{s}BMS%iBatteryCapacity{m}%.2fAh{e}",
                msg, b, self.sepl[b]['BatteryCapacity'])
                
            msg = string.format(
                "%s{s}BMS%iSOC{m}%.2f%%{e}",
                msg, b, self.sepl[b]['SOC'])  
                
            msg = string.format(
                "%s{s}BMS%iRatedCapacity{m}%.2fAh{e}",
                msg, b, self.sepl[b]['RatedCapacity'])
                                
            msg = string.format(
                "%s{s}BMS%iCycleLife{m}%.2f{e}",
                msg, b, self.sepl[b]['CycleLife'])      
            
            msg = string.format(
                "%s{s}BMS%iSOH{m}%.2f%%{e}",
                msg, b, self.sepl[b]['SOH'])  
                
            msg = string.format(
                "%s{s}BMS%iPortVoltage{m}%.2fV{e}",
                msg, b, self.sepl[b]['PortVoltage'])   

            for e:self.warnings                

                if e[0] & 4 == 4 && self.sepl[b].contains(e[2])

                    msg = string.format(
                        "%s{s}BMS%i%s{m}%s{e}",
                        msg, b, e[2], self.sepl[b][e[2]])  
                end
            end
            
            if self.sepl[b].contains('Warnings')

                msg = string.format(
                    "%s{s}BMS%iWarnings{m}%s{e}",
                    msg, b, self.sepl[b]['Warnings'].concat("<br />"))   
            end

            if self.sepl[b].contains('Infos')

                msg = string.format(
                    "%s{s}BMS%iInfo{m}%s{e}",
                    msg, b, self.sepl[b]['Infos'].concat("<br />"))   
            end              
        end

        tasmota.web_send_decimal(msg)
    end

    def json_append()

        var t = self.sepl

        for e:t

            if e.contains('Warnings')

                e['Warnings'] = e['Warnings'].concat(", ")
            end

            if e.contains('Infos')

                e['Infos'] = e['Infos'].concat(", ")
            end            
        end

        tasmota.response_append(
            ',"seplos":'..json.dump(t))
    end

    def requestUpdate(adapter, function, data) 

        self.rxWait = 5

        var p = "20" #ProtocolVersion
        var t = "46" #DeviceType Battery
        var c = 0    #checksum 

        #calculate data size
        var l0 = size(data)
        var l1 = string.format("%03x", l0)
        var l2 = ~(int(l1[0])+int(l1[1])+int(l1[2]))
        l2 = string.format("%X", int('0x'+string.format("%x", l2)[-1])+1)

        var s = bytes().fromstring(
                    p..adapter..t..function..l2..l1..data)   

        #calculate checksum
        for i:0..s.size() - 1
            c += s[i] 
        end

        c = '0x' + string.format("%4X", ~c+1)
        c = c[-4..-1]

        s += bytes().fromstring(c)

        self.ser.write(0x7e)
        self.ser.write(s)
        self.ser.write(0x0d)
    end

    def every_100ms()

        if ! self.rxWait return end

        if self.rxWait <= 0 
            
            if self.rxBuffer.size() > 0

                self.rxBuffer.clear()
            end
        else

            self.rxWait -= 1
        end

        if self.ser.available()

            self.rxBuffer += self.ser.read()
            self.ser.flush()
            self.rxWait += 1
        end

        for i:0..self.rxBuffer.size() - 1

            if self.rxBuffer[i] == 0x0D 

                self.rxCmd(self.rxBuffer[0..i])

                if self.rxBuffer.size() > ( i + 1 )
                    
                    self.rxBuffer = self.rxBuffer[i+1..self.rxBuffer.size()-1]
                else 

                    self.rxBuffer = bytes()
                end
                break
            end
        end
    end

    def every_second()

        if self.updateTeleperiod <= 0

            self.requestUpdate("00", "42", "00", 150)
            self.updateTeleperiod = 15
            return
        else

            self.updateTeleperiod -= 1
        end

        if self.updateInfo <= 0

            self.requestUpdate("00", "44", "00", 150)
            self.updateInfo = 15
            return
        else

            self.updateInfo -= 1
        end        
    end
end  

rs485Driver = rs485()  
tasmota.add_driver(rs485Driver)

#tasmota.remove_driver(rs485Driver)
