# Oregon Weather

Oregon Weather is an app for the Mac that uses a USB RTL-SDR dongle
to receive temperature and humidity data from Oregon Scientific 
THGR122NX temperature/humidity sensors (version 2.1 of the Oregon Scientific
protocol). The code can be easily extended to receive other v2.1 Oregon
Scientific sensors.

## Building

The code is dependent on these libraries:
- libusb
- librtlsdr
- RadioTools (my DSP library). (https://github.com/enlarsen/RadioTools)

Both libusb and the rtlsdr libraries and headers can be obtained from
Brew.

### Installing librtlsdr


```
brew install librtlsdr
```

This will also install the libusb dependency.

## Screenshot

Screenshot of the app with two THGR122NX temperature/humidity sensors:

[![image](https://raw.githubusercontent.com/enlarsen/OregonWeather/master/screenshots/OregonWeatherScreenshot1-thumb.png "Screenshot")](https://raw.githubusercontent.com/enlarsen/OregonWeather/master/screenshots/OregonWeatherScreenshot1.png)

