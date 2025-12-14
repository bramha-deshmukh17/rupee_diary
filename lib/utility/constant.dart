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
  'Food',
  'Fuel',
  'Transport',
  'Grocery',
  'Utilities',
  'Rent/Mortgage',
  'Medical',
  'Education',
  'Shopping',
  'Entertainment',
  'Personal Care',
  'Insurance',
  'Phone/Internet',
  'Subscription',
  'Loan Payment',
  'Credit Card',
  'Clothes',
  'Travel',
  'Bills',
  'Gifts',
  'Others',
];

final Map<String, IconData> categoryIcons = {
  'Food': FontAwesomeIcons.bowlRice,
  'Fuel': FontAwesomeIcons.gasPump,
  'Transport': FontAwesomeIcons.bus,
  'Grocery': FontAwesomeIcons.basketShopping,
  'Utilities': FontAwesomeIcons.receipt,
  'Rent/Mortgage': FontAwesomeIcons.house,
  'Medical': FontAwesomeIcons.briefcaseMedical,
  'Education': FontAwesomeIcons.graduationCap,
  'Shopping': FontAwesomeIcons.bagShopping,
  'Entertainment': FontAwesomeIcons.film,
  'Personal Care': FontAwesomeIcons.spa,
  'Insurance': FontAwesomeIcons.shield,
  'Phone/Internet': FontAwesomeIcons.wifi,
  'Subscription': FontAwesomeIcons.repeat,
  'Loan Payment': FontAwesomeIcons.landmark,
  'Credit Card': FontAwesomeIcons.creditCard,
  'Clothes': FontAwesomeIcons.shirt,
  'Travel': FontAwesomeIcons.plane,
  'Bills': FontAwesomeIcons.fileInvoice,
  'Gifts': FontAwesomeIcons.gift,
  'Income':FontAwesomeIcons.arrowDownLong,
  'Lend': FontAwesomeIcons.handsHoldingCircle,
  'Borrow': FontAwesomeIcons.handsHoldingCircle,
  'Settlement': FontAwesomeIcons.handshake,
  'Others': FontAwesomeIcons.question,
};

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
);

// OutlineInputBorder 
const kOutlineInputBorder = OutlineInputBorder(
  borderSide: BorderSide(color: kSecondaryColor),
  borderRadius: BorderRadius.all(Radius.circular(8.0)),
);
const kFocusedOutlineInputBorder = OutlineInputBorder(
  borderSide: BorderSide(color: kSecondaryColor, width: 2),
  borderRadius: BorderRadius.all(Radius.circular(8.0)),
);

final kBaseOutlineDecoration = InputDecoration(
  border: kOutlineInputBorder,
  focusedBorder: kFocusedOutlineInputBorder,
);
