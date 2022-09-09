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

class seplos

    var _
    var c
    var _attr

    def setmember(name, value)
        self._attr[name] = value
    end

    def member(name)
        if self._attr.contains(name)
            return self._attr[name]
        else
            import undefined
            return undefined
        end
    end

    def init(cmd)

        self._attr = {}

        #data frame design
        self._ = { 150: { 
            "offset": 17,
            "definition": [
                #type, length, converter, name
                #type 0 = dummy, 1 = simple, 2 = multiple
                [1, 4, 0, 'Cell'],
                [1, 4, 1, 'Temperature'],
                [2, 4, 0, 'Current', 100.00],
                [2, 4, 0, 'PackVoltage', 100.00],
                [2, 4, 0, 'RemainingCapacity', 100.00],
                [0, 2],
                [2, 4, 0, 'BatteryCapacity', 100.00],
                [2, 4, 0, 'SOC', 10.00],
                [2, 4, 0, 'RatedCapacity', 100.00],
                [2, 4, 0, 'CycleLife', 100.00],
                [2, 4, 0, 'SOH', 10.00],
                [2, 4, 0, 'PortVoltage', 100.00]
        ]}}

        #converter
        self.c = [
            def(n) return int( '0x' + n.asstring() ) end,
            def(n) return ( int( '0x' + n.asstring() ) - 2731.0 ) / 10.0 end
        ]

        #command size
        var s = self.c[0](cmd[10..12]) 
        
        if self._.contains(s)

            var o = self._[s]['offset']

            for e:self._[s]["definition"]

                #type
                if e[0] > 0

                    #Count with multiple results
                    if e[0] == 1

                        var n = self.c[0](cmd[o..o+1])
                        o += 2

                        if n > 0 && n <=16

                            self.setmember(e[3], [])

                            for c:0..n - 1

                                self.member(e[3]).push(
                                    self.c[e[2]](cmd[o..(o+e[1]-1)]))
                                o += e[1]
                            end
                        end
                    #simple results
                    elif e[0] == 2

                        self.setmember(e[3], 
                            self.c[e[2]](cmd[o..(o+e[1]-1)]))
                        o += e[1]

                        if e.size() > 2

                            self.setmember(e[3], self.member(e[3]) / e[4])
                        end
                    end
                else

                    o += e[1]
                end
            end
        end
    end
end

class rs485 : Driver

    var updateTeleperiod
    var updateInfo

    var debug
    var rxWait
    var rxBuffer
    var rxBufferReset

    var sep 
    var sepl
    var warnings

    var fanTemp
    var s

    static ser = serial(17, 16, 19200, serial.SERIAL_8N1)

    def init()

        self.fanTemp = 26
        self.sep = ", "
        self.sepl = {}

        self.debug = 1

        self.updateInfo = 0
        self.updateTeleperiod = 0

        self.rxBuffer = bytes()
    end

    def rxCmd(cmd)

        self.s = seplos(cmd)
        print(self.s._attr)
        print(self.s.Cell)
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

    def every_250ms()

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

        if self.updateTeleperiod >= 14

            if self.sepl.contains(0)

                if self.sepl[0].contains('Temperatures')

                    if self.sepl[0]['Temperatures'].size() >= 3

                        if self.sepl[0]['Temperatures'][4] > self.fanTemp

                            gpio.pin_mode(2, gpio.PULLUP)
                            self.sepl[0]['Fan'] = 1
                        elif self.sepl[0]['Temperatures'][4] < self.fanTemp - 1

                            gpio.pin_mode(2, gpio.PULLDOWN)
                            self.sepl[0]['Fan'] = 0
                        end
                    end
                end
            end
        end        
    end
end  

tasmota.remove_driver(rs485Driver)

rs485Driver = rs485()  
tasmota.add_driver(rs485Driver)
