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

    var upd
    var debug
    var rxBuffer
    var rxBufferReset

    var sepl

    static ser = serial(17, 16, 19200, serial.SERIAL_8N1)

    def init()

        self.sepl = map()
        self.upd = 0
        self.debug = 1
        self.rxBufferReset = 0

        print("init()")
        self.rxBuffer = bytes()
    end

    def rxCmd(cmd)

        var infoSize = int('0x'+cmd[10..12].asstring()) 

        ##150(75 byte) = Telemetry, 98(49 byte) = Telecommand, 48(24 byte) = Alarm
        if cmd[7..8].asstring() == "00" && infoSize == 150

            var offset = 17

            #bms address
            var bmsAddress = int('0x'+cmd[3..4].asstring())
            if ! self.sepl.find(bmsAddress)
                
                print("add: "..bmsAddress)
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
                int('0x'+cmd[offset..offset+3].asstring()) / 100.00
            offset += 4

            #bms port voltage
            self.sepl[bmsAddress]['PortVoltage'] = 
                int('0x'+cmd[offset..offset+3].asstring()) / 100.00
            offset += 4

            
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
        end

        tasmota.web_send_decimal(msg)
    end

    def json_append()

        tasmota.response_append(
            ',"seplos":'..json.dump(self.sepl))
    end

    def requestUpdate(adapter, function, data) 

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

    def every_250ms()

        if self.rxBufferReset <= 0 
            
            if self.rxBuffer.size() > 0

                self.rxBuffer.clear()
            end
        else

            self.rxBufferReset -= 1
        end

        if self.ser.available()

            self.rxBuffer += self.ser.read()
            self.ser.flush()
            self.rxBufferReset = 10
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

        if self.upd <= 0

            self.requestUpdate("00", "42", "00")
            self.upd = 10
        else

            self.upd -= 1
        end
    end
end  

rs485Driver = rs485()  
tasmota.add_driver(rs485Driver)

#tasmota.remove_driver(rs485Driver)