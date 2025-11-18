import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const Color kPrimaryColor = Color(0xFFFF7043);
const Color kSecondaryColor = Color(0xFF6A1B9A);
const Color kOutline = Color(0xFF540F84);

const Color kWhite = Colors.white;
const Color kBlack = Colors.black;
const Color kRed = Colors.red;
const Color kBlue = Colors.blue;
const Color kGreen = Colors.green;
const Color kGrey = Colors.grey;

const khBox = SizedBox(height: 15.0);
const kwBox = SizedBox(width: 15.0);
const kBox = SizedBox(height: 15.0, width: 15.0,);

// app bar back icon
const Icon kBackArrow = Icon(
  FontAwesomeIcons.arrowLeft,
  size: 20.0,
);

//Category icons
final List<String> categories = [
  'Utilities',
  'Rent/Mortgage',
  'Insurance',
  'Phone/Internet',
  'Subscription',
  'Loan Payment',
  'Credit Card',
  'Other',
];

final Map<String, IconData> categoryIcons = {
  'Utilities': FontAwesomeIcons.receipt,
  'Rent/Mortgage': FontAwesomeIcons.house,
  'Insurance': FontAwesomeIcons.shieldHalved,
  'Phone/Internet': FontAwesomeIcons.wifi,
  'Subscription': FontAwesomeIcons.repeat,
  'Loan Payment': FontAwesomeIcons.landmark,
  'Credit Card': FontAwesomeIcons.creditCard,
  'Other': FontAwesomeIcons.shapes,
};

// ---- Input border/decoration constants ----
const kOutlineBorder = OutlineInputBorder(
  borderSide: BorderSide(color: kSecondaryColor),
);
const kFocusedOutlineBorder = OutlineInputBorder(
  borderSide: BorderSide(color: kSecondaryColor, width: 2),
);

const kBaseInputDecoration = InputDecoration(
  border: kOutlineBorder,
  focusedBorder: kFocusedOutlineBorder,
);
