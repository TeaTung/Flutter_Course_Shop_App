import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shop_app/screens/products_overview_screen.dart';
import '../models/http_exception.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class Auth with ChangeNotifier {
  String? _token;
  DateTime? _expiryDate;
  String? _userId;
  Timer? _authTimer;

  bool? get isAuth {
    print('IS_AUTH ${token != 'null' ? 'isAuth' : 'isNotAuth'}');
    return token != 'null';
  }

  String? get token {
    if (_expiryDate != null &&
        _expiryDate!.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return 'null';
  }

  String? get userId {
    return _userId;
  }

  Future<void> _authenticate(String email, String password, String urlSegment,
      BuildContext context) async {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key=AIzaSyBiHaGNWtbcTZmi_1uEnEloAFgSTDDdDR0');
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'email': email,
            'password': password,
            'returnSecureToken': true,
          },
        ),
      );
      final responseData = json.decode(response.body);
      if (responseData['error'] != null)
        throw HttpException(responseData['error']['message']);
      print(responseData);
      _token = responseData['idToken'];
      print('TOKEN: $_token');
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );
      _autoLogout(context);
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode({
        'token': _token,
        'userId': _userId,
        'expiryDate': _expiryDate!.toIso8601String(),
      });
      prefs.setString('userData', userData);
      notifyListeners();
    } catch (error) {
      print(error.toString());
    } finally {}
  }

  Future<bool> tryAutoLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData =
        json.decode(prefs.getString('userData')!) as Map<String, dynamic>;
    final expiryDate = DateTime.parse(extractedUserData['expiryDate']!);
    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }
    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;
    notifyListeners();
    Navigator.of(context).pushNamed(ProductsOverviewScreen.routeName);
    _autoLogout(context);
    return true;
  }

  Future<void> signUp(
      String email, String password, BuildContext context) async {
    return _authenticate(email, password, 'signUp', context);
  }

  Future<void> login(
      String email, String password, BuildContext context) async {
    return _authenticate(email, password, 'signInWithPassword', context);
  }

  Future<void> logout(BuildContext context) async {
    _token = 'null';
    _userId = 'null';
    _expiryDate = DateTime.now();
    print('AUTH STATE: $isAuth');
    if (_authTimer != null) {
      _authTimer!.cancel();
    }

    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
    notifyListeners();
    Navigator.of(context).pushNamed('/');
  }

  void _autoLogout(BuildContext context) {
    if (_authTimer != null) {
      _authTimer!.cancel();
      _authTimer = null;
    }
    final timeToExpiry = _expiryDate!.difference(DateTime.now()).inSeconds;

    _authTimer = Timer(Duration(seconds: timeToExpiry), () => logout(context));
  }
}
