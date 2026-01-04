import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const Color kPrimaryColor = Color(0xFF10B981);
const Color kSecondaryColor =  Color.fromARGB(255, 68, 196, 153);

const Color kWhite = Colors.white;
const Color kBlack = Colors.black;
const Color kRed = Colors.red;
const Color kBlue = Colors.blue;
const Color kGreen = Colors.green;
const Color kGrey = Colors.grey;

const khBox = SizedBox(height: 15.0);
const kwBox = SizedBox(width: 15.0);
const kBox = SizedBox(height: 15.0, width: 15.0);

// app bar back icon
const Icon kBackArrow = Icon(FontAwesomeIcons.arrowLeft, size: 20.0);

// UnderlineInputBorder
const kOutlineBorder = UnderlineInputBorder(
  borderSide: BorderSide(color: kSecondaryColor),
);
const kFocusedOutlineBorder = UnderlineInputBorder(
  borderSide: BorderSide(color: kSecondaryColor, width: 2),
);

const kBaseInputDecoration = InputDecoration(
  border: kOutlineBorder,
  focusedBorder: kFocusedOutlineBorder,
  enabledBorder: kOutlineBorder,
);