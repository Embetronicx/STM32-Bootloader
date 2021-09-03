import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flashy/cfg_color.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:flutter/cupertino.dart';
import 'package:wakelock/wakelock.dart';

final int ETX_OTA_SOF  = 0xAA;                  // Start of Frame
final int ETX_OTA_EOF  = 0xBB;                  // End of Frame
final int ETX_OTA_ACK  = 0x00;                  // ACK
final int ETX_OTA_NACK = 0x01;                  // NACK

final int ETX_OTA_PACKET_TYPE_CMD       = 0;    // Command
final int ETX_OTA_PACKET_TYPE_DATA      = 1;    // Data
final int ETX_OTA_PACKET_TYPE_HEADER    = 2;    // Header
final int ETX_OTA_PACKET_TYPE_RESPONSE  = 3;    // Response

final int ETX_OTA_CMD_START = 0;                // OTA Start command
final int ETX_OTA_CMD_END   = 1;                // OTA End command
final int ETX_OTA_CMD_ABORT = 2;                // OTA Abort command

final int ETX_OTA_DATA_MAX_SIZE = 1024;         //Maximum data Size
final int ETX_OTA_DATA_OVERHEAD = 9;            //data overhead

final command  = Uint8List(10);
final header   = Uint8List(25);
PlatformFile file;
BluetoothCharacteristic G_characteristic;
var should_stop = false;

final List<int> crc_table = [
  0x00000000, 0x04C11DB7, 0x09823B6E, 0x0D4326D9, 0x130476DC, 0x17C56B6B, 0x1A864DB2, 0x1E475005, 0x2608EDB8, 0x22C9F00F, 0x2F8AD6D6, 0x2B4BCB61, 0x350C9B64, 0x31CD86D3, 0x3C8EA00A, 0x384FBDBD,
  0x4C11DB70, 0x48D0C6C7, 0x4593E01E, 0x4152FDA9, 0x5F15ADAC, 0x5BD4B01B, 0x569796C2, 0x52568B75, 0x6A1936C8, 0x6ED82B7F, 0x639B0DA6, 0x675A1011, 0x791D4014, 0x7DDC5DA3, 0x709F7B7A, 0x745E66CD,
  0x9823B6E0, 0x9CE2AB57, 0x91A18D8E, 0x95609039, 0x8B27C03C, 0x8FE6DD8B, 0x82A5FB52, 0x8664E6E5, 0xBE2B5B58, 0xBAEA46EF, 0xB7A96036, 0xB3687D81, 0xAD2F2D84, 0xA9EE3033, 0xA4AD16EA, 0xA06C0B5D,
  0xD4326D90, 0xD0F37027, 0xDDB056FE, 0xD9714B49, 0xC7361B4C, 0xC3F706FB, 0xCEB42022, 0xCA753D95, 0xF23A8028, 0xF6FB9D9F, 0xFBB8BB46, 0xFF79A6F1, 0xE13EF6F4, 0xE5FFEB43, 0xE8BCCD9A, 0xEC7DD02D,
  0x34867077, 0x30476DC0, 0x3D044B19, 0x39C556AE, 0x278206AB, 0x23431B1C, 0x2E003DC5, 0x2AC12072, 0x128E9DCF, 0x164F8078, 0x1B0CA6A1, 0x1FCDBB16, 0x018AEB13, 0x054BF6A4, 0x0808D07D, 0x0CC9CDCA,
  0x7897AB07, 0x7C56B6B0, 0x71159069, 0x75D48DDE, 0x6B93DDDB, 0x6F52C06C, 0x6211E6B5, 0x66D0FB02, 0x5E9F46BF, 0x5A5E5B08, 0x571D7DD1, 0x53DC6066, 0x4D9B3063, 0x495A2DD4, 0x44190B0D, 0x40D816BA,
  0xACA5C697, 0xA864DB20, 0xA527FDF9, 0xA1E6E04E, 0xBFA1B04B, 0xBB60ADFC, 0xB6238B25, 0xB2E29692, 0x8AAD2B2F, 0x8E6C3698, 0x832F1041, 0x87EE0DF6, 0x99A95DF3, 0x9D684044, 0x902B669D, 0x94EA7B2A,
  0xE0B41DE7, 0xE4750050, 0xE9362689, 0xEDF73B3E, 0xF3B06B3B, 0xF771768C, 0xFA325055, 0xFEF34DE2, 0xC6BCF05F, 0xC27DEDE8, 0xCF3ECB31, 0xCBFFD686, 0xD5B88683, 0xD1799B34, 0xDC3ABDED, 0xD8FBA05A,
  0x690CE0EE, 0x6DCDFD59, 0x608EDB80, 0x644FC637, 0x7A089632, 0x7EC98B85, 0x738AAD5C, 0x774BB0EB, 0x4F040D56, 0x4BC510E1, 0x46863638, 0x42472B8F, 0x5C007B8A, 0x58C1663D, 0x558240E4, 0x51435D53,
  0x251D3B9E, 0x21DC2629, 0x2C9F00F0, 0x285E1D47, 0x36194D42, 0x32D850F5, 0x3F9B762C, 0x3B5A6B9B, 0x0315D626, 0x07D4CB91, 0x0A97ED48, 0x0E56F0FF, 0x1011A0FA, 0x14D0BD4D, 0x19939B94, 0x1D528623,
  0xF12F560E, 0xF5EE4BB9, 0xF8AD6D60, 0xFC6C70D7, 0xE22B20D2, 0xE6EA3D65, 0xEBA91BBC, 0xEF68060B, 0xD727BBB6, 0xD3E6A601, 0xDEA580D8, 0xDA649D6F, 0xC423CD6A, 0xC0E2D0DD, 0xCDA1F604, 0xC960EBB3,
  0xBD3E8D7E, 0xB9FF90C9, 0xB4BCB610, 0xB07DABA7, 0xAE3AFBA2, 0xAAFBE615, 0xA7B8C0CC, 0xA379DD7B, 0x9B3660C6, 0x9FF77D71, 0x92B45BA8, 0x9675461F, 0x8832161A, 0x8CF30BAD, 0x81B02D74, 0x857130C3,
  0x5D8A9099, 0x594B8D2E, 0x5408ABF7, 0x50C9B640, 0x4E8EE645, 0x4A4FFBF2, 0x470CDD2B, 0x43CDC09C, 0x7B827D21, 0x7F436096, 0x7200464F, 0x76C15BF8, 0x68860BFD, 0x6C47164A, 0x61043093, 0x65C52D24,
  0x119B4BE9, 0x155A565E, 0x18197087, 0x1CD86D30, 0x029F3D35, 0x065E2082, 0x0B1D065B, 0x0FDC1BEC, 0x3793A651, 0x3352BBE6, 0x3E119D3F, 0x3AD08088, 0x2497D08D, 0x2056CD3A, 0x2D15EBE3, 0x29D4F654,
  0xC5A92679, 0xC1683BCE, 0xCC2B1D17, 0xC8EA00A0, 0xD6AD50A5, 0xD26C4D12, 0xDF2F6BCB, 0xDBEE767C, 0xE3A1CBC1, 0xE760D676, 0xEA23F0AF, 0xEEE2ED18, 0xF0A5BD1D, 0xF464A0AA, 0xF9278673, 0xFDE69BC4,
  0x89B8FD09, 0x8D79E0BE, 0x803AC667, 0x84FBDBD0, 0x9ABC8BD5, 0x9E7D9662, 0x933EB0BB, 0x97FFAD0C, 0xAFB010B1, 0xAB710D06, 0xA6322BDF, 0xA2F33668, 0xBCB4666D, 0xB8757BDA, 0xB5365D03, 0xB1F740B4,
];

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flashy',
    theme: ThemeData(
      primarySwatch: Palette.kToDark,
    ),
    home:  StreamBuilder<BluetoothState>(
        stream: FlutterBlue.instance.state,
        initialData: BluetoothState.unknown,
        builder: (c, snapshot) {
          final state = snapshot.data;
          if (state == BluetoothState.on) {
            return MyHomePage(title: "EmbeTronicX Flashy");
          }
          return BluetoothOffScreen(state: state);
        }),
  );
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subhead
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _writeController = TextEditingController();
  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.state.listen((state) {
      if (state == BluetoothState.off) {
        //Alert user to turn on bluetooth.
        print("Enable BLE");
        var alertStyle = AlertStyle(
          isCloseButton: false,
          isOverlayTapDismiss: false,
        );
        Alert(
            context: context,
            style: alertStyle,
            title: "Enable Bluetooth",
            useRootNavigator: false,
            buttons: [
              DialogButton(
                onPressed: () {
                  should_stop = true;
                  Navigator.of(
                      context, rootNavigator: true)
                      .pop();
                },
                child: Text(
                  "Okay",
                  style: TextStyle(
                      color: Colors.white, fontSize: 10),
                ),
              )
            ]).show();
      } else if (state == BluetoothState.on) {
        //if bluetooth is enabled then go ahead.
      }
    });

    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  ListView _buildListViewOfDevices() {
    List<Container> containers = new List<Container>();
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        Container(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unknown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              ),
              FlatButton(
                color: Colors.green,
                child: Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                  } catch (e) {
                    if (e.code != 'already_connected') {
                      throw e;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(
      BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = new List<ButtonTheme>();

    if (characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              color: Colors.green,
              child: Text('READ', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                var sub = characteristic.value.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.read();
                sub.cancel();
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.write) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: Text('WRITE', style: TextStyle(color: Colors.white)),
              onPressed: () {
                should_stop = false;
                G_characteristic = characteristic;
                _onAlertWithRootNavigator(context);
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: Text('NOTIFY', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                characteristic.value.listen((value) {
                  widget.readValues[characteristic.uuid] = value;
                });
                await characteristic.setNotifyValue(true);
              },
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  ListView _buildConnectDeviceView() {
    List<Container> containers = new List<Container>();

    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = new List<Widget>();

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Text('Value: ' +
                        widget.readValues[characteristic.uuid].toString()),
                  ],
                ),
                Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        Container(
          child: ExpansionTile(
              title: Text(service.uuid.toString()),
              children: characteristicsWidget),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  ListView _buildView() {
    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    return _buildListViewOfDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
    ),
    body: _buildView(),
  );

  void sendBLE( List<int> data, BluetoothCharacteristic characteristic ) {
    for (var e in data) {
        sleep(Duration(milliseconds:50));
        print(e);
        characteristic.write(Uint8List.fromList([e]), withoutResponse: true);
    }

    /*
    print(data);

    int start = 0;
    int size = 1;
    for(int i = 0; i < data.length; ) {
      Timer(Duration(milliseconds: 10), ()
      {
        characteristic.write(
            Uint8List.fromList(data.sublist(start, start + size)),
            withoutResponse: true);

        /*
      for (var i = 0; i < 99999; i++) {
        for (var i = 0; i < 100; i++) {
          //I don't know to add the proper delay. So just added for loop delay.
          if (should_stop == true) {
            return;
          }
        }
      }
       */
        start += size;
      });
    }
     */
    //TODO: Implement Read and Verify response
  }

  Uint8List getOtaCommand ( int cmd ) {
    command[0] = ETX_OTA_SOF;               //Start of frame
    command[1] = ETX_OTA_PACKET_TYPE_CMD;   //Command type
    command[2] = 0x01;                      //Len LSB
    command[3] = 0x00;                      //Len MSB
    command[4] = cmd;                       //cmd

    int crc = CalcCRC([cmd]);
    command[5] = (crc >>  0) & 0x000000FF;  //CRC LSB
    command[6] = (crc >>  8) & 0x000000FF;  //CRC
    command[7] = (crc >> 16) & 0x000000FF;  //CRC
    command[8] = (crc >> 24) & 0x000000FF;  //CRC MSB
    command[9] = ETX_OTA_EOF;               //End of frame

    return command;
  }

  Uint8List getOtaHeader ( int package_size, int package_crc ) {
    header[0]  = ETX_OTA_SOF;                         //Start of frame
    header[1]  = ETX_OTA_PACKET_TYPE_HEADER;          //Header type
    header[2]  = 0x10;                                //Len LSB
    header[3]  = 0x00;                                //Len MSB
    header[4]  = (package_size >>  0) & 0x000000FF;   //Data
    header[5]  = (package_size >>  8) & 0x000000FF;   //Data
    header[6]  = (package_size >> 16) & 0x000000FF;   //Data
    header[7]  = (package_size >> 24) & 0x000000FF;   //Data

    header[8]  = (package_crc >>  0) & 0x000000FF;    //Data
    header[9]  = (package_crc >>  8) & 0x000000FF;    //Data
    header[10] = (package_crc >> 16) & 0x000000FF;    //Data
    header[11] = (package_crc >> 24) & 0x000000FF;    //Data

    header[12] = 0x00;                                //Reserved Data
    header[13] = 0x00;                                //Reserved Data
    header[14] = 0x00;                                //Reserved Data
    header[15] = 0x00;                                //Reserved Data
    header[16] = 0x00;                                //Reserved Data
    header[17] = 0x00;                                //Reserved Data
    header[18] = 0x00;                                //Reserved Data
    header[19] = 0x00;                                //Reserved Data

    int crc = CalcCRC(header.sublist(4, 20));
    header[20] = (crc >>  0) & 0x000000FF;            //CRC LSB
    header[21] = (crc >>  8) & 0x000000FF;            //CRC
    header[22] = (crc >> 16) & 0x000000FF;            //CRC
    header[23] = (crc >> 24) & 0x000000FF;            //CRC MSB
    header[24] = ETX_OTA_EOF;                         //End of frame

    return header;
  }

  List<int> getOtaData ( List<int> data ) {
    final List<int> ota_data = [];
    ota_data.add( ETX_OTA_SOF );                         //Start of frame
    ota_data.add( ETX_OTA_PACKET_TYPE_DATA );            //Data type
    ota_data.add( data.length & 0xFF );                  //Len LSB
    ota_data.add( (data.length >> 8) & 0xFF );           //Len MSB
    ota_data.addAll(Uint8List.fromList(data));                               //Data

    int crc = CalcCRC(data);
    ota_data.add( (crc >>  0) & 0x000000FF );            //CRC LSB
    ota_data.add( (crc >>  8) & 0x000000FF );            //CRC
    ota_data.add( (crc >> 16) & 0x000000FF );            //CRC
    ota_data.add( (crc >> 24) & 0x000000FF );            //CRC MSB
    ota_data.add( ETX_OTA_EOF );                         //End of frame

    return ota_data;
  }

  int CalcCRC(List<int> data)
  {
    Uint8List bytes = Uint8List.fromList(data);
    int Checksum = 0xFFFFFFFF;

    for (var e in bytes) {
      int top = (Checksum >> 24);
      top = (top & 0xFF) ^ e;
      Checksum = (Checksum << 8) ^ crc_table[top];
    }

    return Checksum;
  }

  List chunk(Uint8List list, int chunkSize) {
    List chunks = [];
    int len = list.length;
    for (var i = 0; i < len; i += chunkSize) {
      int size = i+chunkSize;
      chunks.add(list.sublist(i, size > len ? len : size));
    }
    return chunks;
  }

  _onAlertWithRootNavigator(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(icon: Icon(Icons.info)),
                  BottomNavigationBarItem(icon: Icon(Icons.search))
                ],
              ),
              tabBuilder: (BuildContext context, int index) {
                return CupertinoTabView(
                  builder: (BuildContext context) {
                    return CupertinoPageScaffold(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Firmware OTA is about to Start. Please Select the Firmware File!!!",
                            style: TextStyle(inherit: false, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                          ElevatedButton(
                            child: Text('PICK FILE'),
                            onPressed: () async {
                              FilePickerResult result = await FilePicker.platform.pickFiles( withData: true);
                              if(result != null) {
                                file = result.files.first;
                                if (file.extension == "bin") {
                                  print(" File Name : " + file.name);
                                  print("File Size : " + file.size.toString());

                                  print("FIle PATH : " + file.path);

                                  _onAlertWithRootNavigator1(context);
                                } else {
                                  Alert(
                                      context: context,
                                      title: "Please select the bin file!!!",
                                      useRootNavigator: false,
                                      buttons: [
                                        DialogButton(
                                          onPressed: () =>
                                              Navigator.of(
                                                  context, rootNavigator: true)
                                                  .pop(),
                                          child: Text(
                                            "Okay",
                                            style: TextStyle(
                                                color: Colors.white, fontSize: 10),
                                          ),
                                        )
                                      ]).show();
                                }
                              }
                              else {
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      ),
    );
  }

  _onAlertWithRootNavigator1(BuildContext context) {

    Navigator.of(context, rootNavigator: true).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(icon: Icon(Icons.info)),
                  BottomNavigationBarItem(icon: Icon(Icons.search))
                ],
              ),
              tabBuilder: (BuildContext context, int index) {
                return CupertinoTabView(
                  builder: (BuildContext context) {
                    return CupertinoPageScaffold(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "You have selected the " +file.name +". Firmware OTA is about to Start. Press the START!!!",
                            style: TextStyle(inherit: false, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                          ElevatedButton(
                            child: Text('START'),
                            onPressed: () {

                              var alertStyle = AlertStyle(
                                isCloseButton: false,
                                isOverlayTapDismiss: false,
                              );


                              Alert(
                                  context: context,
                                  style: alertStyle,
                                  title: "FOTA In progress. Wait until it finishes!!!",
                                  useRootNavigator: false,
                                  buttons: [
                                    DialogButton(
                                      onPressed: () async {
                                        should_stop = true;
                                        Navigator.of(
                                            context, rootNavigator: true)
                                            .pop();
                                      },
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                    )
                                  ]).show();

                              // To keep the screen on:
                              Wakelock.enable();

                              //Timer(Duration(seconds: 1), () {
                                File _file = new File(file.path);
                                var file_contents = _file.readAsBytesSync();

                                //Initiate the OTA process
                                G_characteristic.write(utf8.encode("ota"));
                                sleep(Duration(seconds:2));

                                //wait for 1 sec and do the OTA process
                                Timer(Duration(seconds: 1), () {
                                  //send OTA START
                                  print("Sending OTA START");
                                  sendBLE(getOtaCommand(ETX_OTA_CMD_START),
                                      G_characteristic);

                                  //Send OTA HEADER
                                  print("Sending OTA HEADER");
                                  sendBLE(getOtaHeader(
                                      file.size, CalcCRC(file.bytes)),
                                      G_characteristic);

                                  //Split the data
                                  int len = file.size;
                                  int start = 0;

                                  print("Sending OTA DATA");
                                  for (start = 0; start < file.size;) {
                                    if (should_stop == true) {
                                      break;
                                    }
                                    int size = ((file.size - start) >
                                        ETX_OTA_DATA_MAX_SIZE)
                                        ? ETX_OTA_DATA_MAX_SIZE
                                        : (file.size - start);
                                    print("Size = " + size.toString());

                                    //Send OTA DATA Chunk
                                    sendBLE(getOtaData(file_contents.sublist(
                                        start, start + size)),
                                        G_characteristic);
                                    print("Start = " + start.toString() +
                                        " End = " + (start + size).toString());
                                    //print(contents.sublist(start, start+size));
                                    if (start == 0) {
                                      sleep(Duration(seconds:5));
                                      /*
                                      //Add some delay for the first chunk.
                                      for (var i = 0; i < 99999; i++) {
                                        for (var i = 0; i < 9999; i++) {
                                          //I don't know to add the proper delay. So just added for loop delay.
                                        }
                                      }

                                       */
                                    }
                                    start += size;
                                  }

                                  //send OTA END
                                  print("Sending OTA END");
                                  sendBLE(getOtaCommand(ETX_OTA_CMD_END),
                                      G_characteristic);

                                  // To let the screen turn off again:
                                  Wakelock.disable();

                                  showDialog(
                                      context: context,
                                      useRootNavigator: false,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: new Text('Success!!!'),
                                          content: Text(
                                              "Firmware Download Successfully Finished!!!"),
                                          actions: <Widget>[
                                            TextButton(
                                              child: Text("Okay"),
                                              onPressed: () {
                                                Navigator.of(
                                                    context, rootNavigator: true)
                                                    .pop();
                                              },
                                            ),
                                          ],
                                        );
                                      });

                                });
                              //});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}