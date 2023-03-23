import 'dart:convert';
import 'dart:developer';

import 'package:app/main.dart';
import 'package:app/models/store_credential_data.dart';
import 'package:flutter/material.dart';

import 'package:app/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/demo_method_channel.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  SettingsState createState() => SettingsState();

}

class SettingsState extends State<Settings> {
  final TextEditingController usernameController = TextEditingController();
  final Future<SharedPreferences> prefs = SharedPreferences.getInstance();
  bool isSwitched = false;
  String walletSDKVersion  = '';
  String gitRevision  = '';
  String buildTimeRev  = '';

  checkDevMode() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    setState(() {
      isSwitched = preferences.getBool('devmode') ?? false;
    });
  }
  @override
  initState() {
    checkDevMode();
    getUserDetails();
    getVersionDetails();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Settings'),
          backgroundColor: const Color(0xffEEEAEE),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 1.0],
                    colors: <Color>[
                      Color(0xff261131),
                      Color(0xff100716),
                    ])
            ),
          ),
        ),
        body: Container(
          height: 900,
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: TextFormField(
                    enabled: false,
                    controller: usernameController,
                    decoration: const InputDecoration(
                      fillColor:  Color(0xff8D8A8E),
                      border: UnderlineInputBorder(),
                      labelText: 'Username',
                      labelStyle: TextStyle(color: Color(0xff190C21), fontWeight: FontWeight.w700,
                          fontFamily: 'SF Pro', fontSize: 16, fontStyle: FontStyle.normal ),
                    )
                ),
              ),
              SwitchListTile(
                value: isSwitched,
                title: const Text("Dev Mode", style:TextStyle(color: Color(0xff190C21), fontWeight: FontWeight.w700,
                    fontFamily: 'SF Pro', fontSize: 14, fontStyle: FontStyle.normal )),
                onChanged: (value) {
                  setState(() {
                    isSwitched = value;
                  });
                  saveDevMode();
                },
                activeTrackColor: Colors.deepPurple,
                activeColor: Colors.deepPurpleAccent,
              ),
              const Spacer(),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    width: 327,
                    child: PrimaryButton(
                      gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xffFFFFFF), Color(0xffFFFFFF)]),
                      onPressed: () {
                        signOut();
                      },
                      child: const Text('Sign Out', style: TextStyle(fontSize: 16, color: Color(0xff6C6D7C))),
                      // trying to move to the bottom
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Text('Version: $walletSDKVersion',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, color: Color(0xff6C6D7C))
                      ),
                    ),
                  Align(
                  alignment: Alignment.center,
                    child: Text('GitRevision: $gitRevision',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xff6C6D7C))
                    )
                  ),
                Align(
                  alignment: Alignment.center,
                   child: Text('Build Time: $buildTimeRev',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xff6C6D7C))
                    ),
                  )
                  ],

                 ),
              ),
            ],
          ),
        )
    );
  }

  saveDevMode() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool('devmode',isSwitched);
  }

  getVersionDetails() async {
    var walletSDKPlugin = MethodChannelWallet();
    var versionDetailResp = await walletSDKPlugin.getVersionDetails();
    var didDocEncoded = json.encode(versionDetailResp!);
    Map<String, dynamic> responseJson = json.decode(didDocEncoded);
    walletSDKVersion = responseJson["walletSDKVersion"];
    gitRevision = responseJson["gitRevision"];
    buildTimeRev = responseJson["buildTimeRev"];
  }
  getUserDetails() async {
    UserLoginDetails userLoginDetails =  await getUser();
    log("userLoginDetails -> $userLoginDetails");
    usernameController.text = userLoginDetails.username!;
  }
  initPreferences() async {
    final SharedPreferences  prefs =  await SharedPreferences.getInstance();
    return prefs.getBool("devmode")!;
  }

  signOut() async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyApp()));
  }
}