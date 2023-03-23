import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app/models/credential_data.dart';
import 'package:app/main.dart';

class CredentialMetaDataCard extends StatefulWidget {
  CredentialData credentialData;

  CredentialMetaDataCard({required this.credentialData, Key? key}) : super(key: key);
  @override
  State<CredentialMetaDataCard> createState() => CredentialMetaDataCardState();
}

  class CredentialMetaDataCardState extends State<CredentialMetaDataCard> {
    String issueDate = '';
    String expiryDate = '';
    dynamic credentialClaimsData = [];
    bool isLoading = false;

    @override
    void initState() {
      setState(() {
        isLoading = true;
      });
      super.initState();
      WalletSDKPlugin.resolveCredentialDisplay(widget.credentialData.credentialDisplayData).then(
              (response) {
            setState(() {
              var credentialDisplayEncodeData = json.encode(response);
              List<dynamic> responseJson = json.decode(credentialDisplayEncodeData);
              credentialClaimsData = responseJson.first['claims'];
              isLoading = false;
            });
          });
    }

    getIssuanceDate() {
      var claimsList = credentialClaimsData;
      for (var claims in claimsList) {
        if (claims["label"].toString().contains("Issue Date")) {
          var issueDate = claims["rawValue"];
          return issueDate;
        }
      }
      final now = DateTime.now();
      String formatter = DateFormat('yMMMMd').format(now); // 28/03/2020
      return formatter;
    }

    getExpiryDate() {
      var claimsList = credentialClaimsData;
      for (var claims in claimsList) {
        if (claims["label"].toString().contains("Expiry Date")) {
          var expiryDate = claims["rawValue"];
          return expiryDate;
        }
      }
      return 'Never';
    }

    @override
    Widget build(BuildContext context) {
      return  isLoading ? const Center(child: LinearProgressIndicator()):Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(4, 4),
                )
              ]),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: SizedBox(
                    height: 60,
                    child: ListTile(
                        title: const Text(
                          'Added on',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff190C21),
                          ),
                          textAlign: TextAlign.start,
                        ),
                        subtitle: Text(
                          getIssuanceDate(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xff6C6D7C),
                          ),
                          textAlign: TextAlign.start,
                        )
                    ),
                  )
              ),
              Flexible(
                  child: SizedBox(
                      height: 60,
                      child: ListTile(
                          title: const Text(
                            'Expires on',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff190C21),
                            ),
                            textAlign: TextAlign.start,
                          ),
                          //TODO need to add fallback and network image url
                          subtitle: Text(
                            getExpiryDate(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xff6C6D7C),
                            ),
                            textAlign: TextAlign.start,
                          )
                      )
                  )
              ),
            ],
          )
      );
    }
  }