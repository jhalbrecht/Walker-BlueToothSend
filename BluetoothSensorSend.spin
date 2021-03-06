{{
  BluetoothSensorSend.spin
  Began July 24, 2013
  Jeff Albrecht @jhalbrecht

        Parallax propeller board of education
        Bluetooth RN-41 in XBEE form factor
        SHT-11 temperature and humidity
        Polar heart rate monitor

        Send data via bluetooth to windows phone application; Walker activity tracker
                create .gpx file allow persist to SkyDrive
                Report activity data to windows azures

  Revision history:

  July 25, 2013
        Add timer routines to calculate pulse rate

}}

CON

  _clkmode = xtal1 + pll16x     'Use the PLL to multiple the external clock by 16
  _xinfreq = 5_000_000          'An external clock of 5MHz. is used (80MHz. operation

 TX_PIN        = 19                                    ' jha for serial LCD   
 BAUD          = 19_200
 
 SHT_DATA      = 14 '26 '24 ' 29                                    ' SHT-11 data pin
 SHT_CLOCK     = 15 '27 '25 ' 28                                    ' SHT-11 clock pin

 HR_RX          = 0

 CR            = 13
 LF            = 10                                                                                                                                               

VAR

  long  rawTemp, tempC, beatCounter, beats, beatsPerMinute
  byte  oldSample
  byte  sample

  long IHeartTimeUpdateStack[128] 'Stack space for gitErDone cog
  long IHeartTimeUpdateID   

OBJ

  PlxST         : "Parallax Serial Terminal"
'  LCD           : "FullDuplexSerial.spin"
  blueTooth     : "FullDuplexSerial.spin"

  sht           : "Sensirion_full"
  fp            : "FloatString"
  f             : "Float32"

PUB Main  | rh, rawHumidity

  dira[HR_RX]~                  'Set heart rate signal pin to input

  

  PlxST.Start(115_200)
  PauseMSec(2_000)

'   LCD.start(TX_PIN, TX_PIN, %1000, 19_200)
  pausemsec(100)

  blueTooth.start(6, 7, %1000, 115_200)
  pausemsec(100)
  
  PlxST.Home
  PlxST.Clear

  f.start                                               ' start floating point object
  sht.start(SHT_DATA, SHT_CLOCK)                        ' start sensirion object

  sht.config(33,sht#off,sht#yes,sht#hires)        '1 slow, hiRes measurement

  pausemsec(2000)  ' fudge during debugging to get the terminal open.

  ' start Polar heart beat receiver in it's own cog
  if IHeartTimeUpdateID := cognew(IHeartTime, @IHeartTimeUpdateStack)
    plxst.str(string(cr,lf,"IHeartTime cog start succeeded.",cr,lf))
  else
    plxst.str(string(cr,lf,"IHeartTime cog start failed.",cr,lf)) 
  
  repeat
'    sht.config(33,sht#off,sht#yes,sht#hires)        '1 slow, hiRes measurement 
    rawTemp := f.FFloat(sht.readTemperature)
    tempC := celsius(rawTemp)
    PlxST.Str(string("Temperature : "))
    PlxSt.str(fp.FloatToFormat(fahrenheit(tempC), 5,1))    ' print temperature in degrees fahrenheit      
    plxst.str(string(cr,lf))
    rawHumidity := f.FFloat(sht.readHumidity)
    rh := humidity(tempC, rawHumidity)
    PlxST.Str(string("Humidity : "))    
    PlxSt.str(fp.FloatToFormat(rh, 5, 1))
    plxst.str(string(cr,lf))  
        
    ' lcd.str(string("LCD Walker",CR,LF))

    blueTooth.str(string("Temperature : "))
    blueTooth.str(fp.FloatToFormat(fahrenheit(tempC), 5,1))
    blueTooth.str(string("|"))

    blueTooth.str(string("Humidity : "))
    blueTooth.str(fp.FloatToFormat(rh, 5, 1))
    blueTooth.str(string("|"))

    ' pause 15 seconds. Get current heart beat count. Multiply by 4 for rate per minute. 
    PauseMSec(15000)
    beats := beatCounter
    beatsPerMinute := beats * 4
    plxst.str(string("beatsPerMinute: "))     ' send via bluetooth
    plxst.dec(beatsPerMinute)
    plxst.str(string(cr,lf))
    blueTooth.str(string("Heart : "))
    blueTooth.dec(beatsPerMinute)
    blueTooth.str(string("|"))  
    beatCounter := 0  

PUB IHeartTime

    beatCounter := 1
    ' plxst.str(fp.floattoformat(beats,5,1))
    'plxst.str(string("IHeartTime Cog begin."))
    plxst.dec(beatCounter)
    
    repeat
  
      sample := ina[HR_RX]    'Store signal output
      if sample and oldSample <> sample
        beatCounter := beatCounter + 1
       ' PlxST.str(string(" beatCounter: "))
       ' PlxSt.dec(beatCounter)
       
      oldSample := sample     'Store last signal received
       

PRI PauseMSec(Duration)

''  Pause execution for specified milliseconds.
''  This routine is based on the set clock frequency.
''  
''  params:  Duration = number of milliseconds to delay                                                                                               
''  return:  none
  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)

  return  'end of PauseMSec

PUB celsius(t)
    ' from SHT1x/SHT7x datasheet using value for 3.5V supply
    ' celsius = -39.7 + (0.01 * t)
'    return f.FAdd(-39.7, f.FMul(0.01, t))
    'return f.FAdd(-39.875, f.FMul(0.01, t))   ' ~ 4.5vdc
     return f.FAdd(-40.0, f.FMul(0.01, t))   ' 5vdc

PUB fahrenheit(t)
    ' fahrenheit = (celsius * 1.8) + 32
    return f.FAdd(f.FMul(t, 1.8), 32.0)

PUB humidity(t, rh) | rhLinear
  ' rhLinear = -2.0468 + (0.0367 * rh) + (-1.5955E-6 * rh * rh)
  ' simplifies to: rhLinear = ((-1.5955E-6 * rh) + 0.0367) * rh -2.0468
  rhLinear := f.FAdd(f.FMul(f.FAdd(0.0367, f.FMul(-1.5955E-6, rh)), rh), -2.0468)
  ' rhTrue = (t - 25.0) * (0.01 + 0.00008 * rawRH) + rhLinear
  return f.FAdd(f.FMul(f.FSub(t, 25.0), f.FAdd(0.01, f.FMul(0.00008, rh))), rhLinear)


con
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
  