# SmartThingsEdge-Xiaomi
The early adaptation of the SmartThings Edge drivers from https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers
for Xiaomi and Aqara devices


# Platform known issues 

https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/issues

# How to install

Channel invitation link 
https://api.smartthings.com/invitation-web/accept?id=5e5b1616-90cf-4383-83ea-a323aac0ed5a

the channel contains the development version of drivers, so it can be unstable.


# How to contribute
- Fork this repository
- Create a branch for your changes
- Make your changes
- Create a pull request
- Wait for the CI to complete
- Wait for the PR to be reviewed and merged


# Supported devices
| Device |  | Zigbee ID |  Device Type | Neutral | Notes ||
--------------------------------|------------------|------------------|----------------------|------------------------|-----------------------|----------------------
| [QBKG03LM](https://zigbee.blakadder.com/Aqara_QBKG03LM.html) | ![QBKG03LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG03LM.webp) | lumi.ctrl_neutral2 | Wall Switch| No Neutral | Double Rocker |
| [QBKG04LM](https://zigbee.blakadder.com/Aqara_QBKG04LM.html) | ![QBKG04LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG04LM.webp) | lumi.ctrl_neutral1 | Wall Switch| With Neutral | Single Rocker |
| [QBKG11LM](https://zigbee.blakadder.com/Aqara_QBKG11LM.html) | ![QBKG11LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG11LM.webp) | lumi.ctrl_ln1 | Wall Switch| With Neutral | Single Rocker |
| [QBKG12LM](https://zigbee.blakadder.com/Aqara_QBKG12LM.html) | ![QBKG12LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG12LM.webp) | lumi.ctrl_ln2, lumi.ctrl_ln1.aq1  | Wall Switch| With Neutral | Double Rocker |
| [QBKG21LM](https://zigbee.blakadder.com/Aqara_QBKG21LM.html) | ![QBKG21LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG21LM.webp) | lumi.b1lacn02 | Wall Switch| No Neutral | Single Rocker |
| [QBKG22LM](https://zigbee.blakadder.com/Aqara_QBKG22LM.html) | ![QBKG22LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG22LM.webp) | lumi.b2lacn02 | Wall Switch| No Neutral | Double Rocker |
| [QBKG23LM](https://zigbee.blakadder.com/Aqara_QBKG23LM.html) | ![QBKG23LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG23LM.webp) | lumi.b1nacn02 | Wall Switch| With Neutral | Single Rocker |
| [QBKG24LM](https://zigbee.blakadder.com/Aqara_QBKG24LM.html) | ![QBKG24LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG24LM.webp) | lumi.b2nacn02 | Wall Switch| With Neutral | Double Rocker |
| [QBKG25LM](https://zigbee.blakadder.com/Aqara_QBKG25LM.html) | ![QBKG25LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG25LM.webp) | lumi.l3acn3 | Wall Switch| No Neutral | Triple Rocker |
| [QBKG26LM](https://zigbee.blakadder.com/Aqara_QBKG26LM.html) | ![QBKG26LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG26LM.webp) | lumi.switch.n3acn3 | Wall Switch| No Neutral | Triple Rocker |
| [QBKG34LM](https://zigbee.blakadder.com/Aqara_QBKG34LM.html) | ![QBKG34LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG34LM.webp) | lumi.switch.b3n01 | Wall Switch| With Neutral | Triple Rocker |
| [QBKG38LM](https://zigbee.blakadder.com/Aqara_QBKG38LM.html) | ![QBKG38LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG38LM.webp) | lumi.switch.b1lc04 | Wall Switch| No Neutral | Single Rocker |
| [QBKG39LM](https://zigbee.blakadder.com/Aqara_QBKG39LM.html) | ![QBKG39LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBKG39LM.webp) | lumi.switch.b2lc04 | Wall Switch| No Neutral | Double Rocker |
| [WS-EUK01](https://zigbee.blakadder.com/Aqara_WS-EUK01.html) | ![WS-EUK01](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-EUK01.webp) | lumi.switch.l1aeu1 | Wall Switch | No Neutral | Single Rocker |
| [WS-EUK02](https://zigbee.blakadder.com/Aqara_WS-EUK02.html) | ![WS-EUK02](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-EUK02.webp) | lumi.switch.l2aeu1 | Wall Switch | No Neutral | Double Rocker |
| [WS-EUK03](https://zigbee.blakadder.com/Aqara_WS-EUK03.html) | ![WS-EUK03](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-EUK03.webp) | lumi.switch.n1aeu1 | Wall Switch | With Neutral | Single Rocker |
| [WS-EUK04](https://zigbee.blakadder.com/Aqara_WS-EUK04.html) | ![WS-EUK04](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-EUK04.webp) | lumi.switch.n2aeu1 | Wall Switch | With Neutral | Double Rocker |
| [WS-USC01](https://zigbee.blakadder.com/Aqara_WS-USC01.html) | ![WS-USC01](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-USC01.webp) | lumi.switch.b1laus01 | Wall Switch | No Neutral | Single Rocker |
| [WS-USC02](https://zigbee.blakadder.com/Aqara_WS-USC02.html) | ![WS-USC02](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-USC02.webp) | lumi.switch.b2laus01 | Wall Switch | No Neutral | Double Rocker |
| [WS-USC03](https://zigbee.blakadder.com/Aqara_WS-USC03.html) | ![WS-USC03](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-USC03.webp) | lumi.switch.b1naus01 | Wall Switch | With Neutral | Single Rocker |
| [WS-USC04](https://zigbee.blakadder.com/Aqara_WS-USC04.html) | ![WS-USC04](https://zigbee.blakadder.com/assets/images/devices/Aqara_WS-USC04.webp) | lumi.switch.b2naus01 | Wall Switch | With Neutral | Double Rocker |
 **Wireless** |
| [WXKG01LM](https://zigbee.blakadder.com/Xiaomi_WXKG01LM.html) | ![WXKG01LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_WXKG01LM.webp) | lumi.sensor_switch | Wireless Switch | - | Single | 
| [WXKG02LM](https://zigbee.blakadder.com/Aqara_WXKG02LM.html) | ![WXKG02LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WXKG02LM.webp) | lumi.sensor_86sw2, lumi.remote.b286acn01 | Wall Switch| - | Double Rocker |
| [WXKG03LM](https://zigbee.blakadder.com/Xiaomi_WXKG03LM.html) | ![WXKG03LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WXKG03LM.webp) | lumi.sensor_86sw1, lumi.remote.b186acn01 | Wall Switch| - | Single Rocker |
| [WXKG06LM](https://zigbee.blakadder.com/Aqara_WXKG06LM.html) | ![WXKG06LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WXKG06LM.webp) | lumi.remote.b186acn02 | Wall Switch| - | Single Rocker |
| [WXKG07LM](https://zigbee.blakadder.com/Aqara_WXKG07LM.html) | ![WXKG07LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WXKG07LM.webp) | lumi.remote.b286acn02 | Wall Switch| - | Double Rocker |
| [WXKG11LM](https://zigbee.blakadder.com/Aqara_WXKG11LM.html) | ![WXKG11LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WXKG11LM.webp) | lumi.sensor_switch.aq2, lumi.remote.b1acn01 | Wall Switch| - | Single |
| [WXKG12LM](https://zigbee.blakadder.com/Aqara_WXKG12LM.html) | ![WXKG12LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WXKG12LM.webp) | lumi.sensor_switch.aq3, lumi.sensor_swit | Wall Switch| - | Single |
| [WXCJKG11LM](https://zigbee.blakadder.com/Xiaomi_WXCJKG11LM.html) | ![WXCJKG11LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_WXCJKG11LM.webp) | lumi.remote.b286opcn01 | Wireless Switch | - | Two Button |
| [WXCJKG12LM](https://zigbee.blakadder.com/Xiaomi_WXCJKG12LM.html) | ![WXCJKG12LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_WXCJKG12LM.webp) | lumi.remote.b486opcn01 | Wireless Switch | - | Four Button |
| [WXCJKG13LM](https://zigbee.blakadder.com/Xiaomi_WXCJKG13LM.html) | ![WXCJKG13LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_WXCJKG13LM.webp) | lumi.remote.b686opcn01 | Wireless Switch | - | Six Button |
| [WRS-R02](https://zigbee.blakadder.com/Aqara_WRS-R02.html) | ![WRS-R02](https://zigbee.blakadder.com/assets/images/devices/Aqara_WRS-R02.webp) | lumi.remote.b28ac1 | Wireless Switch | - | Two Button |
Plugs and Outlets |
| [ZNCZ02LM](https://zigbee.blakadder.com/Xiaomi_ZNCZ02LM.html) | ![ZNCZ02LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_ZNCZ02LM.webp) | lumi.plug | Plug | - | - |
| [ZNCZ03LM](https://zigbee.blakadder.com/Xiaomi_ZNCZ03LM.html) | ![ZNCZ03LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_ZNCZ03LM.webp) | lumi.plug.mitw01 | Plug | - | - |
| [ZNCZ04LM](https://zigbee.blakadder.com/Xiaomi_ZNCZ04LM.html) | ![ZNCZ04LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_ZNCZ04LM.webp) | lumi.plug.mmeu01 | Plug | - | - |
| [ZNCZ11LM](https://zigbee.blakadder.com/Aqara_ZNCZ11LM.html) | ![ZNCZ11LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_ZNCZ11LM.webp) | lumi.plug.aq1 | Plug | - | - |
| [ZNCZ12LM](https://zigbee.blakadder.com/Xiaomi_ZNCZ12LM.html) | ![ZNCZ12LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_ZNCZ12LM.webp) | lumi.plug.maus01 | Plug | - | - |
| [SP-EUC01](https://zigbee.blakadder.com/Aqara_SP-EUC01.html) | ![SP-EUC01](https://zigbee.blakadder.com/assets/images/devices/Aqara_SP-EUC01.webp) | lumi.plug.maeu01 | Plug | - | - |
| [QBCZ11LM](https://zigbee.blakadder.com/Aqara_QBCZ11LM.html) | ![QBCZ11LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_QBCZ11LM.webp) | lumi.ctrl_86plug. lumi.ctrl_86plug.aq1 | Plug | - | - |
Cube |
| [MFKZQ01LM](https://zigbee.blakadder.com/Aqara_MFKZQ01LM.html) | ![MFKZQ01LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_MFKZQ01LM.webp) | lumi.sensor_cube, lumi.sensor_cube.aqgl01 | Cube | - | - |
Curtain Motors and Roller Blinds |
| [ZNCLDJ12LM](https://zigbee.blakadder.com/Aqara_ZNCLDJ12LM.html) | ![ZNCLDJ12LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_ZNCLDJ12LM.webp) | lumi.curtain.hagl04 | Curtain | - | - |
| [E1757](https://zigbee.blakadder.com/Ikea_E1757.html) | ![E1757](https://zigbee.blakadder.com/assets/images/devices/Ikea_E1757.webp) |FYRTUR block-out roller blind | Roller Blind | - | - |
| [E1926](https://zigbee.blakadder.com/Ikea_E1926.html) | ![E1926](https://zigbee.blakadder.com/assets/images/devices/Ikea_E1926.webp) | KADRILJ roller blind | Roller Blind | - | - |
| [E2103](https://zigbee.blakadder.com/Ikea_E2103.html) | ![E2103](https://zigbee.blakadder.com/assets/images/devices/Ikea_E2103.webp) | TREDANSEN block-out cellul blind | Roller Blind | - | - |
Leak and Smoke | Detectors |
| [SJCGQ11LM](https://zigbee.blakadder.com/Aqara_SJCGQ11LM.html) | ![SJCGQ11LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_SJCGQ11LM.webp) | lumi.sensor_wleak.aq1 | Water Leak Sensor | - | - |
| [JTYJ-GD-01LM/BW](https://zigbee.blakadder.com/Xiaomi_JTYJ-GD-01LM_BW.html) | ![JTYJ-GD-01LM/BW](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_JTYJ-GD-01LM_BW.webp) | lumi.sensor_smoke | Smoke Detector | - | - |
| [JY-GZ-01AQ](https://zigbee.blakadder.com/Aqara_JY-GZ-01AQ.html) | ![JY-GZ-01AQ](https://zigbee.blakadder.com/assets/images/devices/Aqara_JY-GZ-01AQ.webp) | lumi.sensor_smoke.acn03 | Smoke Detector | - | - |
Temperature and Humidity |
| [WSDCGQ01LM](https://zigbee.blakadder.com/Xiaomi_WSDCGQ01LM.html) | ![WSDCGQ01LM](https://zigbee.blakadder.com/assets/images/devices/Xiaomi_WSDCGQ01LM.webp) | lumi.sens, lumi.sensor_ht | Temperature and Humidity Sensor | - | - |
| [WSDCGQ11LM](https://zigbee.blakadder.com/Aqara_WSDCGQ11LM.html) | ![WSDCGQ11LM](https://zigbee.blakadder.com/assets/images/devices/Aqara_WSDCGQ11LM.webp) | lumi.weather | Temperature, Humidity and Pressure Sensor | - | - |
